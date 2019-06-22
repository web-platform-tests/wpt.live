#!/usr/bin/env python3

import argparse
import logging
import subprocess
import time

def setup_logging():
    logger = logging.getLogger('sync-wpt')
    handler = logging.StreamHandler()
    formatter = logging.Formatter(
        '%(asctime)s %(name)-12s %(levelname)-8s %(message)s'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)
    return logger

def main(remote, branch, period):
    logger = setup_logging()

    while True:
        logger.debug('Fetching latest revision.')

        subprocess.check_call(['git', 'fetch', remote, branch])

        current = subprocess.check_output(['git', 'rev-parse', 'HEAD']).strip()
        fetched = subprocess.check_output(['git', 'rev-parse', 'FETCH_HEAD']).strip()

        logger.debug('current:%s', current)
        logger.debug('fetched:%s', fetched)

        if current != fetched:
            break

        logger.debug('Nothing to do. Sleeping for %d seconds.', period)
        time.sleep(period)

    logger.debug('Updating working tree.')

    subprocess.check_call(['git', 'reset', '--hard', fetched])

    logger.debug('All done')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--remote', required=True)
    parser.add_argument('--branch', required=True)
    parser.add_argument('--period', required=True, type=int)

    main(**vars(parser.parse_args()))
