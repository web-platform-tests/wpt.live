#!/usr/bin/env python3

import json
import sys
import urllib.request

latest = {
    'identifier': None,
    'time_created': 0
}

with urllib.request.urlopen(sys.argv[1]) as contents:
    for identifier, metadata in json.load(contents).get('manifest').items():
        time_created = int(metadata.get('timeCreatedMs'))
        if  time_created > latest['time_created']:
            latest['identifier'] = identifier
            latest['time_created'] = time_created

    if latest['identifier'] is None:
        raise ValueError('No images defined.')

    print(latest['identifier'])
