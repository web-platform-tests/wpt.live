#!/usr/bin/env python3

import argparse
import ConfigParser
import hmac
import json
import lockfile
import os
import shutil
import subprocess
import sys
from urlparse import urljoin

import requests

config = None
config_path = '~/sync.ini'


class MasterCheckout(object):
    def __init__(self, path):
        self.path = path

    @classmethod
    def create(cls, path, remote):
        rv = cls(path)
        git('clone', remote, os.path.join(path, 'tmp'), cwd=path)
        os.rename(
            os.path.join(path, 'tmp', '.git'), os.path.join(path, '.git')
        )
        git('reset', '--hard', 'HEAD', cwd=path)
        git(
            'config', '--add', 'remote.origin.fetch',
            '+refs/pull/*/head:refs/remotes/origin/pr/*', cwd=path
        )
        git('config', 'gc.auto', '0', cwd=path)
        git('fetch', 'origin', cwd=path)
        git('submodule', 'init', cwd=path)
        git('submodule', 'update', '--recursive', cwd=path)
        return rv

    def update(self):
        git('fetch', 'origin', cwd=self.path)
        git('checkout', '-f', 'origin/master', cwd=self.path)
        git('submodule', 'update', '--recursive', cwd=self.path)


class PullRequestCheckout(object):
    def __init__(self, path, number):
        self.number = number
        self.path = path

    @classmethod
    def exists(cls, base_path, number):
        return os.path.exists(
            os.path.join(base_path, 'submissions', str(number), '.git')
        )

    @classmethod
    def from_number(cls, base_path, number):
        path = os.path.join(base_path, 'submissions', str(number))
        if os.path.exists(path):
            return cls(path, number)

    @classmethod
    def create(cls, base_path, number):
        path = os.path.join(base_path, 'submissions', str(number))
        rv = cls(path, number)
        if not os.path.exists(path):
            os.mkdir(path)
            git(
                'clone', '--shared', '--no-checkout', base_path, path,
                cwd=path
            )
            git('submodule', 'init', cwd=path)
            git(
                'config', '--add', 'remote.origin.fetch',
                '+refs/remotes/origin/pr/*:refs/pr/*', cwd=path
            )
        elif not PullRequestCheckout.exists(base_path, number):
            raise IOError(
                'Expected git repository in path %s, got something else' % path
            )
        rv.update()
        return rv

    def delete(self):
        shutil.rmtree(self.path)

    def update(self):
        git('fetch', 'origin', cwd=self.path)
        git('checkout', '-f', 'refs/pr/%i' % self.number, '--', cwd=self.path)
        git('submodule', 'update', '--recursive', cwd=self.path)


def git(command, *args, **kwargs):
    cwd = kwargs.get('cwd')
    if cwd is None:
        raise ValueError()
    no_throw = kwargs.get('no_throw', False)
    cmd = ['git', command] + list(args)
    print(cwd, repr(cmd), file=sys.stderr)
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd
    )
    stdout, stderr = proc.communicate()
    print(stdout + '\n' + stderr, file=sys.stderr)
    if proc.returncode != 0:
        if no_throw:
            return False
        else:
            raise IOError(stderr)
    return True


def is_authorised_user(config, login):
    resp = requests.get(
        'https://api.github.com/repos/%s/%s/collaborators/%s' % (
            config['org_name'], config['repo_name'], login
        ), auth=(config['username'], config['password'])
    )
    return resp.status_code == 204


def process_pull_request(config, data, user_is_authorised):
    base_path = config['base_path']

    update_master(base_path)
    action = data['action']

    action_handlers = {'opened': pull_request_opened,
                       'reopened': pull_request_opened,
                       'labeled': pull_request_noop,
                       'unlabeled': pull_request_noop,
                       'edited': pull_request_noop,
                       'assigned': pull_request_noop,
                       'review_requested': pull_request_noop,
                       'review_dismissed': pull_request_noop,
                       'review_request_removed': pull_request_noop,
                       'closed': end_mirror,
                       'synchronize': sync_mirror}
    action_handlers[action](
        base_path, data['pull_request']['number'], user_is_authorised
    )


def pull_request_opened(base_path, number, user_is_authorised):
    if user_is_authorised:
        start_mirror(base_path, number, user_is_authorised)


def pull_request_noop(base_path, number, user_is_authorised):
    pass


def start_mirror(base_path, number, user_is_authorised):
    if not PullRequestCheckout.exists(base_path, number):
        PullRequestCheckout.create(base_path, number)
    else:
        PullRequestCheckout.from_number(base_path, number).update()


def end_mirror(base_path, number, user_is_authorised):
    if PullRequestCheckout.exists(base_path, number):
        PullRequestCheckout.from_number(base_path, number).delete()

        # There's nothing to link back to, so delete the comment doing so
        delete_issue_comments(number)


def sync_mirror(base_path, number, user_is_authorised):
    if PullRequestCheckout.exists(base_path, number):
        PullRequestCheckout.from_number(base_path, number).update()


def process_push(config):
    update_master(config['base_path'])


def command(comment):
    commands = ['mirror', 'unmirror']
    for command in commands:
        if comment.startswith('w3c-test:%s' % command):
            return command
    print('No command found in comment', file=sys.stderr)


def process_issue_comment(config, data, user_is_authorised):
    comment = data['comment']['body']

    if 'pull_request' not in data['issue']:
        return
    if data['issue']['pull_request']['diff_url'] is None:
        return
    elif not command(comment):
        return
    elif not user_is_authorised:
        return
    else:
        update_master(config['base_path'])
        filename = data['issue']['pull_request']['html_url'].rsplit('/', 1)[1]
        pull_request_number = int(os.path.splitext(filename)[0])
        action_handlers = {'mirror': start_mirror,
                           'unmirror': end_mirror}
        action_handlers[command(comment)](
            config['base_path'], pull_request_number, user_is_authorised
        )


def update_master(base_path):
    checkout = MasterCheckout(base_path)
    checkout.update()


def update_pull_requests(base_path):
    submissions_path = os.path.join(base_path, 'submissions')
    for fn in os.listdir(submissions_path):
        try:
            number = int(fn)
        except ValueError:
            continue
        if PullRequestCheckout.exists(base_path, number):
            PullRequestCheckout(
                os.path.join(submissions_path, str(number)), number
            ).update()


def post_authentic(config, body, signature):
    if not signature:
        print('Signature missing', file=sys.stderr)
        return False
    expected = 'sha1=%s' % hmac.new(config['secret'], body).hexdigest()
    print(
        'Signature got %s, expected %s' % (signature, expected),
        file=sys.stderr
    )
    # XXX disable this for now
    return True
    return signature == expected


def delete_issue_comments(issue_number):
    '''Delete all user's comments in the issue containing the magic string.'''
    user_name = config['username']
    auth = (user_name, config['password'])
    issues_url = 'https://api.github.com/repos/%s/%s/issues/' % (
        config['org_name'], config['repo_name']
    )
    issue_comments = requests.get(
        urljoin(issues_url, '%s/comments' % issue_number), auth=auth
    ).json()

    # Assuming that some bug or other condition may have caused multiple
    # comments from this bot, delete them all.
    for comment in issue_comments:
        if comment['user']['login'] == user_name and (
                'These tests are now available' in comment['body']):
            requests.delete(
                urljoin(issues_url, 'comments/%s' % comment['id']), auth=auth
            )


def main(request, response):
    global config
    config = get_config()
    data = request.body

    lock = lockfile.FileLock(config['lockfile'])
    try:
        lock.acquire(timeout=120)
        if data:
            print(data, file=sys.stderr)
            if not post_authentic(
                    config, data, request.headers['X-Hub-Signature']):
                print('Got message with incorrect signature', file=sys.stderr)
                return
            data = json.loads(data)

            if 'commits' in data:
                process_push(config)
            else:
                handlers = {'pull_request': process_pull_request,
                            'comment': process_issue_comment}
                found = False
                for key, handler in handlers.iteritems():
                    if key in data:
                        found = True
                        user_is_authorised = is_authorised_user(
                            config, data[key]['user']['login']
                        )
                        handler(config, data, user_is_authorised)
                        break

                if not found:
                    print(
                        'Unrecognised event type with keys %r' % (
                            data.keys(),
                        ), file=sys.stderr
                    )

    except lockfile.LockTimeout:
        print(
            'Lock file detected for payload %s' % (
                request.headers['X-GitHub-Delivery']
            ), file=sys.stderr
        )
        sys.exit(1)
    finally:
        lock.release()

    response.headers.append('Content-Type', 'text/plain')
    return 'Success'


def create_master(config):
    base_path = config['base_path']
    if not os.path.exists(os.path.join(base_path, 'submissions')):
        os.mkdir(os.path.join(base_path, 'submissions'))
    if not os.path.exists(os.path.join(base_path, '.git')):
        MasterCheckout.create(
            base_path,
            'git://github.com/%s/%s.git' % (
                config['org_name'], config['repo_name']
            )
        )


def get_open_pull_request_numbers(config):
    pull_requests = requests.get(
        'https://api.github.com/repos/%s/%s/pulls' % (
            config['org_name'], config['repo_name']
        ),
        auth=(config['username'], config['password'])
    ).json()
    return [
        item['number'] for item in pull_requests if (
            item['state'] == 'open' and is_authorised_user(
                config, item['user']['login']
            )
        )
    ]


def setup(config):
    create_master(config)
    for number in get_open_pull_request_numbers(config):
        PullRequestCheckout.create(config['base_path'], number)
    register_events(config)


def register_events(config):
    return
    events = ['push', 'pull_request', 'issue_comment']
    data = {
        'name': 'web',
        'events': events,
        'config': {
            'url': config['url'],
            'content_type': 'json',
            'secret': config['secret']
        },
        'active': True
    }
    resp = requests.post(
        'https://api.github.com/repos/%s/%s/hooks' % (
            config['org_name'], config['repo_name']
        ),
        data=json.dumps(data),
        auth=(config['username'], config['password'])
    )
    print('%i\n%s' % (resp.status_code, resp.text), file=sys.stderr)


def get_config():
    config = ConfigParser.RawConfigParser()
    config.read(os.path.abspath(os.path.expanduser(config_path)))
    rv = dict(config.items('sync'))
    if 'base_path' not in rv:
        rv['base_path'] = os.path.abspath(os.path.split(__file__)[0])
    rv['base_path'] = os.path.abspath(os.path.expanduser(rv['base_path']))
    return rv


if __name__ == '__main__':
    config = get_config()
    if '--setup' in sys.argv:
        setup(config)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bucket', dest='bucket_name', required=True)

    main(**vars(parser.parse_args()))
