#!/usr/bin/env python3

import argparse
import hashlib
import logging
import os
import shutil
import subprocess
import tempfile
import time

BUFFER_SIZE = 64 * 1024 # 64 kilobytes

def setup_logging():
    logger = logging.getLogger('fetch-certs')
    handler = logging.StreamHandler()
    formatter = logging.Formatter(
        '%(asctime)s %(name)-12s %(levelname)-8s %(message)s'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)
    return logger

def get_hash(file_name):
    md5 = hashlib.md5()

    with open(file_name, 'rb') as handle:
        while True:
            data = handle.read(BUFFER_SIZE)
            if not data:
                break
            md5.update(data)

    return md5.hexdigest()

def main(bucket_name, period):
    logger = setup_logging()

    while True:
        logger.debug('Fetching certificates.')

        with tempfile.TemporaryDirectory() as tmp_dir:
            subprocess.check_call([
                'gsutil',
                'cp',
                'gs://{}/fullchain.pem'.format(bucket_name),
                'gs://{}/privkey.pem'.format(bucket_name),
                tmp_dir
            ])

            old_fullchain_hash = old_privkey_hash = None

            try:
                old_fullchain_hash = get_hash('/root/fullchain.pem')
                old_privkey_hash = get_hash('/root/privkey.pem')
            except FileNotFoundError:
                pass

            if get_hash('{}/fullchain.pem'.format(tmp_dir)) != old_fullchain_hash or (
                get_hash('{}/privkey.pem'.format(tmp_dir)) != old_privkey_hash):

                logger.debug('New files received. Copying into place.')

                shutil.move('{}/fullchain.pem'.format(tmp_dir), '/root/fullchain.pem')

                shutil.move('{}/privkey.pem'.format(tmp_dir), '/root/privkey.pem')

                break

        logger.debug('Nothing to do. Sleeping for %d seconds.', period)
        time.sleep(period)

    logger.debug('All done')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bucket', dest='bucket_name', required=True)
    parser.add_argument('--period', required=True, type=int)

    main(**vars(parser.parse_args()))
