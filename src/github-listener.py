#!/usr/bin/env python3

import argparse
import flask


def handle_pull_request(data):
    pass


def handle_comment(data):
    pass


def main(host, port, listing):
    app = flask.Flask(__name__)

    @app.route('/', methods=['POST'])
    def index():
        body = flask.request.get_json()

        with open(listing, 'w+') as handle:
            if 'pull_request' in body:
                handle.write('pull request')
            elif 'comment' in body:
                handle.write('comment')

        return ''

    app.run(host=host, port=port)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', required=True)
    parser.add_argument('--port', required=True, type=int)
    parser.add_argument('--listing', required=True)

    main(**vars(parser.parse_args()))
