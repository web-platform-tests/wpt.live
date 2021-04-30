#!/usr/bin/env python3

import argparse
import json
import urllib.request


def main(registry, image):
    url = 'https://{}/v2/{}/tags/list'.format(registry, image)
    latest = {
        'identifier': None,
        'time_created': 0
    }

    with urllib.request.urlopen(url) as contents:
        manifest = json.load(contents).get('manifest')
        for identifier, metadata in manifest.items():
            time_created = int(metadata.get('timeCreatedMs'))
            if time_created > latest['time_created']:
                latest['identifier'] = identifier
                latest['time_created'] = time_created

        if latest['identifier'] is None:
            raise ValueError('No images defined.')

        latest['time_created'] = str(latest['time_created'])

    return latest


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--registry', required=True)
    parser.add_argument('--image', required=True)

    latest = main(**vars(parser.parse_args()))
    print(json.dumps(latest, indent=2))
