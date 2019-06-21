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

from google.cloud import dns
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
# Number of seconds to wait between consecutive queries
CHANGE_POLL_INTERVAL = 5

def qualify_domain(domain):
    if not domain.endswith('.'):
        domain += '.'

    return domain

def unqualify_domain(domain):
    if domain.endswith('.'):
        domain = domain[:-1]

    return domain

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

def request_certificate(email, zone_name, domain_name, aliases):
    '''Retrieve a free TLS certificate for a given domain and set of aliases
    (e.g. example.com and www.example.com) using the ACME protocol as
    implemented by the Certbot application.'''

    fqdn = qualify_domain(domain_name)

    authentication_hook = '{} dns-modify --action create --zone {} --domain {}'.format(
        __file__, zone_name, fqdn
    )
    cleanup_hook = '{} dns-modify --action destroy --zone {} --domain {}'.format(
        __file__, zone_name, fqdn
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


def upload_certificate(bucket_name, domain_name):
    client = storage.Client()
    bucket = client.get_bucket('web-platform-tests-live')

    for file_name in ('fullchain.pem', 'privkey.pem'):
        local_path = '/etc/letsencrypt/live/{}/{}'.format(
            domain_name, file_name
        )
        blob = bucket.blob(file_name)
        blob.upload_from_filename(filename=local_path)

def _dns_modify(action, zone, record_set, max_wait):
    changes = zone.changes()

    if action == 'create':
        changes.add_record_set(record_set)
    else:
        changes.delete_record_set(record_set)

    changes.create()
    start = time.time()

    while changes.status != 'done':
        if time.time() - start > max_wait:
            raise Exception('Timed out')

        time.sleep(CHANGE_POLL_INTERVAL)
        changes.reload()

def dns_modify(action, zone_name, domain_name, max_wait):
    '''Create or destroy a DNS entry as part of the ACME protocol.'''

    client = dns.Client()
    zone = client.zone(zone_name, domain_name)

    record_set_name = '_acme-challenge.{}'.format(
        qualify_domain(os.environ['CERTBOT_DOMAIN'])
    )
    for record_set in zone.list_resource_record_sets():
        if record_set.record_type == 'TXT' and record_set.name == record_set_name:
            _dns_modify('destroy', zone, record_set, max_wait)
            break

    record_set = zone.resource_record_set(
        record_set_name,
        record_type='TXT',
        ttl=30,
        rrdatas=[
            '"{}"'.format(os.environ['CERTBOT_VALIDATION'])
        ]
    )

    if action == 'create':
        _dns_modify(action, zone, record_set, max_wait)

def request(zone_name, domain_name, bucket_name, email, aliases):
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
        |                    | |    +------>| dns_modify (create)  |
        |                    | |    |    |  '----------------------'
        |                    | |    |    |  .----------------------.
        |                    | |    +------>| dns_modify (destroy) |
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

    try:
        request_certificate(email, zone_name, domain_name, aliases)
    except Exception as e:
        logger.critical(
            'Failed to request certificate: {}'.format(e)
        )
        return

    logger.debug('Uploading certificate')

    upload_certificate(bucket_name, domain_name)

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
    parser_request.add_argument('--zone', dest='zone_name', required=True)
    parser_request.add_argument('--domain', dest='domain_name', required=True)
    parser_request.add_argument('--bucket', dest='bucket_name', required=True)
    parser_request.add_argument('--email', required=True)
    parser_request.add_argument('--alias', dest='aliases', action='append',
                                required=True)
    parser_request.set_defaults(func=request)

    parser_modify = subparsers.add_parser(
        'dns-modify', help=dns_modify.__doc__
    )
    parser_modify.add_argument(
        '--action',
        required=True,
        choices=('create', 'destroy')
    )
    parser_modify.add_argument('--zone', dest='zone_name', required=True)
    parser_modify.add_argument('--domain', dest='domain_name', required=True)
    parser_modify.add_argument('--max-wait', type=int, default=DNS_TIMEOUT)
    parser_modify.set_defaults(func=dns_modify)

    args = vars(parser.parse_args())
    func = args.pop('func')
    func(**args)
