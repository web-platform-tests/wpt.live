#!/usr/bin/env python3

import argparse
import contextlib
import datetime
import logging
import os
import socket
import ssl
import subprocess
import time

import boto3
import botocore
from cryptography import x509
from cryptography.hazmat.backends import default_backend

# Based on the following guides:
#
# - https://hackernoon.com/easy-lets-encrypt-certificates-on-aws-79387767830b
# - https://arkadiyt.com/2018/01/26/deploying-effs-certbot-in-aws-lambda/
#
# See also:
#
# - https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/cloudfront.html
# - https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/acm.html

logger = logging.getLogger(__name__)
hostname = socket.gethostname()

# Maximum number of days before "Not Valid After" date
RENEWAL_THRESHOLD = 30
# Maximum number of seconds to wait for a DNS change to be applied
DNS_TIMEOUT = 180

def qualify_domain(domain):
    if not domain.endswith('.'):
        domain += '.'

    return domain

def unqualify_domain(domain):
    if domain.endswith('.'):
        domain = domain[:-1]

    return domain

def get_zone_id(domain):
    response = boto3.client('route53').list_hosted_zones_by_name()
    qualified_domain = qualify_domain(domain)

    for zone in response['HostedZones']:
        if zone['Name'] == qualified_domain:
            return zone['Id']

    raise Exception('No zone found for domain "{}"'.format(domain))

def get_certificate_expiry(fqdn):
    '''Determine the expiration date ("Not valid after") of the TLS certificate
    which is currently in use by a given domain.'''

    context = ssl.create_default_context()
    domain = unqualify_domain(fqdn)

    with socket.create_connection((domain, 443)) as sock:
        try:
            with context.wrap_socket(sock, server_hostname=domain) as sslsock:

                der_cert = sslsock.getpeercert(True)

                # from binary DER format to PEM
                pem_cert = ssl.DER_cert_to_PEM_cert(der_cert)

        # `wrap_socket` will throw in response to expired certificates.
        # Although this script is intended to renew certificates long before
        # they expire, the case is handled to promote resiliency.
        except ssl.SSLError:
            return datetime.datetime(1970, 1, 1)

    cert = x509.load_pem_x509_certificate(
        bytes(pem_cert, 'utf8'), default_backend()
    )

    return cert.not_valid_after

def request_certificate(email, zone_id, domain_name, aliases):
    '''Retrieve a free TLS certificate for a given domain and set of aliases
    (e.g. example.com and www.example.com) using the ACME protocol as
    implemented by the Certbot application.'''

    authentication_hook = '{} update-dns --action UPSERT --zone-id {}'.format(
        __file__, zone_id
    )
    cleanup_hook = '{} update-dns --action DELETE --zone-id {}'.format(
        __file__, zone_id
    )

    # When multiple domains are specified, Certbot interprets the first
    # differently than those that follow it:
    #
    # > The first domain provided will be the subject CN of the certificate, and
    # > all domains will be Subject Alternative Names on the certificate. The
    # > first domain will also be used in some software user interfaces and as
    # > the file paths for the certificate and related material unless otherwise
    # > specified or you already have a certificate with the same name.
    #
    # https://certbot.eff.org/docs/using.html
    #
    # Ensure that the top-level domain name is the first element.
    if domain_name not in aliases:
        raise Exception(
            'Domain name {} not present in the list of aliases'.format(domain_name)
        )
    elif aliases[0] != domain_name:
        aliases.remove(domain_name)
        aliases.insert(0, domain_name)

    subprocess.check_call([
        'certbot', 'certonly',
            '--non-interactive',
            '--agree-tos',
            '--manual',
            '--manual-auth-hook', authentication_hook,
            '--manual-cleanup-hook', cleanup_hook,
            '--preferred-challenge', 'dns',
            '--manual-public-ip-logging-ok',
            '--domains', ','.join(aliases),
            '--email', email
    ])

def upload_certificate(domain_name):
    raise NotImplemented()

def update_dns(action, zone_id, max_wait):
    '''Create or destroy a DNS entry as part of the ACME protocol.'''

    client = boto3.client('route53')

    fqdn = qualify_domain(os.environ['CERTBOT_DOMAIN'])
    comment = '{} managing record for ACME challenge'.format(hostname)
    record_name = '_acme-challenge.{}'.format(fqdn)
    record_value = '"{}"'.format(os.environ['CERTBOT_VALIDATION'])

    response = client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            'Comment': comment,
            'Changes': [
                {
                    'Action': action,
                    'ResourceRecordSet': {
                        'Name': record_name,
                        'ResourceRecords': [
                            { 'Value': record_value }
                        ],
                        'Type': 'TXT',
                        'TTL': 30
                    }
                }
            ]
        }
    )

    request_id = response['ChangeInfo']['Id']

    start_time = time.time()

    while response['ChangeInfo']['Status'] != 'INSYNC':
        if time.time() - start_time > max_wait:
            raise Exception(
                'Waited {} seconds for change to apply'.format(max_wait)
            )

        logger.debug(
            'Change in {} state. Waiting...'.format(
                response['ChangeInfo']['Status']
            )
        )

        time.sleep(1)

        response = client.get_change(Id=request_id)

def request(domain_name, email, aliases):
    '''For all the AWS CloudFront distributions accessible by the current user,
    identify which have been marked for automated TLS certificate renewal, and
    update any certificates which are due to expire.

    This is the entry point of the script.

    The control flow for a single domain can be visualized as follows (each box
    represents a distinct process):

        .--------------------.
        |      request       |
        |         '-----------------.
        |                    |      v
        |                    | .---------.
        |                    | | certbot |  .----------------------.
        |                    | |    +------>| update_dns (create)  |
        |                    | |    |    |  '----------------------'
        |                    | |    |    |  .----------------------.
        |                    | |    +------>| update_dns (destroy) |
        |         .-----------------'    |  '----------------------'
        |         v          | '---------'
        | upload_certificate |
        '--------------------'
    '''

    now = datetime.datetime.now()
    not_valid_after = get_certificate_expiry(domain_name)

    logger.debug('{} will expire on {}'.format(domain_name, not_valid_after))

    if (not_valid_after - now).days > RENEWAL_THRESHOLD:
        logger.debug('no renewal necessary (threshold: {} days)'.format(RENEWAL_THRESHOLD))
        return

    logger.debug('Requesting certificate')

    zone_id = get_zone_id(domain_name)

    try:
        request_certificate(email, zone_id, domain_name, aliases)
    except Exception as e:
        logger.critical(
            'Failed to request certificate: {}'.format(e)
        )
        return

    logger.debug('Uploading certificate')

    upload_certificate(domain_name)

    logger.debug('Successfully uploaded certificate')

if __name__ == '__main__':
    handler = logging.StreamHandler()
    formatter = logging.Formatter(
        '%(asctime)s %(name)-12s %(levelname)-8s %(message)s'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()
    parser.set_defaults(func=request)

    parser_request = subparsers.add_parser('request', help=request.__doc__)
    parser_request.add_argument('--domain', dest='domain_name', required=True)
    parser_request.add_argument('--email', required=True)
    parser_request.add_argument('--alias', dest='aliases', action='append',
                                required=True)
    parser_request.set_defaults(func=request)

    parser_update = subparsers.add_parser(
        'update-dns', help=update_dns.__doc__
    )
    parser_update.add_argument(
        '--action',
        required=True,
        choices=('UPSERT', 'DELETE')
    )
    parser_update.add_argument('--zone-id', required=True)
    parser_update.add_argument('--max-wait', type=int, default=DNS_TIMEOUT)
    parser_update.set_defaults(func=update_dns)

    args = vars(parser.parse_args())
    func = args.pop('func')
    func(**args)
