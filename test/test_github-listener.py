import json
import os
import pytest
import subprocess
import tempfile


full_path = os.path.abspath(
    '{}/../src/github-listener.py'.format(os.path.dirname(__file__))
)


@pytest.fixture
def temp_file():
    name = tempfile.mkstemp()[1]
    yield name
    os.remove(name)


@pytest.fixture
def listener(request):
    def create(listing):
        proc = subprocess.Popen(
            [
                'python', full_path,
                '--host', 'localhost',
                '--port', str(5000),
                '--listing', listing
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        while True:
            try:
                send([])
                break
            except Exception:
                pass

        request.addfinalizer(lambda: proc.kill())

    return create


def send(data):
    proc = subprocess.Popen(
        [
            'curl',
            '--data', json.dumps(data),
            '-H', 'Content-Type: application/json',
            'localhost:5000'
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout = proc.communicate()[0]
    if proc.returncode != 0:
        raise Exception()
    return stdout


def test_open_pull_request(temp_file, listener):
    listener(temp_file)
    send({
        'pull_request': {}
    })
    with open(temp_file) as handle:
        assert handle.read() == 'pull request'


def test_comment(temp_file, listener):
    listener(temp_file)
    send({
        'comment': {}
    })
    with open(temp_file) as handle:
        assert handle.read() == 'comment'
