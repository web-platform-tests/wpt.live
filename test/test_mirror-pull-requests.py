import os
import pytest
import shutil
import subprocess
import tempfile


subject = os.path.join(
    os.path.dirname(__file__), '..', 'src', 'mirror-pull-requests.sh'
)


class Repo(object):
    def __init__(self, cwd):
        self.cwd = cwd
        self.cmd(['git', 'init'])

    def cmd(self, cmd):
        return subprocess.check_output(
            cmd, cwd=self.cwd
        ).decode('utf-8').rstrip()

    def update_ref(self, name, new_value):
        return self.cmd(['git', 'update-ref', name, new_value])

    def delete_ref(self, name):
        return self.cmd(['git', 'update-ref', '-d', name])

    def worktrees(self):
        marker = 'worktree {}/'.format(self.cwd)
        output = self.cmd(['git', 'worktree', 'list', '--porcelain'])
        for line in output.split('\n'):
            if line.startswith(marker):
                yield line[len(marker):]


@pytest.fixture
def repos():
    temp_dirs = []

    def make_repo():
        temp_dir = tempfile.mkdtemp()
        temp_dirs.append(temp_dir)
        return Repo(temp_dir)

    class Repos(object):
        remote = make_repo()
        local = make_repo()

    Repos.remote.cmd([
        'git', 'commit', '--allow-empty', '--message', 'Initial commit'
    ])
    Repos.local.cmd(['git', 'remote', 'add', 'origin', Repos.remote.cwd])
    Repos.local.cmd(['git', 'pull', 'origin', 'master'])

    yield Repos

    for temp_dir in temp_dirs:
        shutil.rmtree(temp_dir)


def test_okay(repos):
    remote_refs = [
        'refs/prs-open/gh-1',
        'refs/prs-open/gh-2',
        'refs/prs-open/gh-3',
        'refs/prs-open/gh-4',
        'refs/prs-trusted-for-preview/gh-2',
        'refs/prs-trusted-for-preview/gh-3',
        'refs/prs-trusted-for-preview/gh-4',
        'refs/prs-trusted-for-preview/gh-5'
    ]
    for ref in remote_refs:
        repos.remote.cmd(['git', 'update-ref', ref, 'HEAD'])
    local_refs = [
        'refs/prs-open/gh-2',
        'refs/prs-open/gh-6',
        'refs/prs-trusted-for-preview/gh-2',
        'refs/prs-trusted-for-preview/gh-6'
    ]
    for ref in local_refs:
        repos.local.cmd(['git', 'update-ref', ref, 'HEAD'])

    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-2', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-6', 'HEAD'])

    subprocess.check_call(subject, cwd=repos.local.cwd)

    expected = set((
        'submissions/gh-2', 'submissions/gh-3', 'submissions/gh-4'
    ))
    assert expected == set(repos.local.worktrees())


def test_create(repos):
    repos.remote.update_ref('refs/prs-open/gh-100', 'HEAD')
    repos.remote.update_ref('refs/prs-open/gh-101', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-100', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-101', 'HEAD')
    # Opened but not trusted:
    repos.remote.update_ref('refs/prs-open/gh-200', 'HEAD')
    repos.remote.update_ref('refs/prs-open/gh-201', 'HEAD')
    # Trusted but not open:
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-300', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-301', 'HEAD')

    subprocess.check_call(subject, cwd=repos.local.cwd)

    expected = set((
        'submissions/gh-100', 'submissions/gh-101'
    ))
    assert expected == set(repos.local.worktrees())


def test_update(repos):
    repos.local.update_ref('refs/prs-open/gh-100', 'HEAD')
    repos.local.update_ref('refs/prs-open/gh-101', 'HEAD')
    repos.local.update_ref('refs/prs-open/gh-200', 'HEAD')
    repos.local.update_ref('refs/prs-open/gh-201', 'HEAD')
    repos.local.update_ref('refs/prs-trusted-for-preview/gh-100', 'HEAD')
    repos.local.update_ref('refs/prs-trusted-for-preview/gh-101', 'HEAD')
    repos.local.update_ref('refs/prs-trusted-for-preview/gh-200', 'HEAD')
    repos.local.update_ref('refs/prs-trusted-for-preview/gh-201', 'HEAD')
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-100', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-101', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-200', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-201', 'HEAD'])

    repos.remote.update_ref('refs/prs-open/gh-100', 'HEAD')
    repos.remote.update_ref('refs/prs-open/gh-101', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-100', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-101', 'HEAD')

    repos.remote.cmd(['git', 'commit', '--allow-empty', '--message', 'second'])
    repos.remote.update_ref('refs/prs-open/gh-200', 'HEAD')
    repos.remote.update_ref('refs/prs-open/gh-201', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-200', 'HEAD')
    repos.remote.update_ref('refs/prs-trusted-for-preview/gh-201', 'HEAD')

    old_revision = repos.remote.cmd(['git', 'rev-parse', 'HEAD~'])
    new_revision = repos.remote.cmd(['git', 'rev-parse', 'HEAD'])

    def get_worktree_revision(name):
        directory = os.path.join(repos.local.cwd, 'submissions', name)

        return subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=directory
        ).decode('utf-8').rstrip()

    subprocess.check_call(subject, cwd=repos.local.cwd)

    assert get_worktree_revision('gh-100') == old_revision
    assert get_worktree_revision('gh-101') == old_revision
    assert get_worktree_revision('gh-200') == new_revision
    assert get_worktree_revision('gh-201') == new_revision


def test_prune_removed_labels(repos):
    refs = [
        'refs/prs-open/gh-11',
        'refs/prs-open/gh-23',
        'refs/prs-open/gh-33',
        'refs/prs-open/gh-45',
        'refs/prs-open/gh-55',
        'refs/prs-trusted-for-preview/gh-11',
        'refs/prs-trusted-for-preview/gh-23',
        'refs/prs-trusted-for-preview/gh-33',
        'refs/prs-trusted-for-preview/gh-45',
        'refs/prs-trusted-for-preview/gh-55'
    ]
    for ref in refs:
        repos.remote.update_ref(ref, 'HEAD')
        repos.local.update_ref(ref, 'HEAD')
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-11', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-23', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-33', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-45', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-55', 'HEAD'])

    # Simulate removing labels
    repos.remote.delete_ref('refs/prs-trusted-for-preview/gh-23')
    repos.remote.delete_ref('refs/prs-trusted-for-preview/gh-45')

    subprocess.check_call(subject, cwd=repos.local.cwd)

    expected = set((
        'submissions/gh-11', 'submissions/gh-33', 'submissions/gh-55'
    ))
    assert expected == set(repos.local.worktrees())


def test_prune_closed_branches(repos):
    refs = [
        'refs/prs-open/gh-11',
        'refs/prs-trusted-for-preview/gh-11',
        'refs/prs-open/gh-23',
        'refs/prs-trusted-for-preview/gh-23',
        'refs/prs-open/gh-33',
        'refs/prs-trusted-for-preview/gh-33',
        'refs/prs-open/gh-45',
        'refs/prs-trusted-for-preview/gh-45',
        'refs/prs-open/gh-55',
        'refs/prs-trusted-for-preview/gh-55'
    ]
    for ref in refs:
        repos.remote.update_ref(ref, 'HEAD')
        repos.local.update_ref(ref, 'HEAD')
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-11', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-23', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-33', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-45', 'HEAD'])
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-55', 'HEAD'])

    # Simulate closing pull requests
    repos.remote.delete_ref('refs/prs-open/gh-23')
    repos.remote.delete_ref('refs/prs-open/gh-45')

    subprocess.check_call(subject, cwd=repos.local.cwd)

    expected = set((
        'submissions/gh-11', 'submissions/gh-33', 'submissions/gh-55'
    ))
    assert expected == set(repos.local.worktrees())


def test_prune_closed_branches_corrupt_worktree(repos):
    refs = [
        'refs/prs-open/gh-11',
        'refs/prs-trusted-for-preview/gh-11',
        'refs/prs-open/gh-23',
        'refs/prs-trusted-for-preview/gh-23',
    ]
    for ref in refs:
        repos.remote.update_ref(ref, 'HEAD')
        repos.local.update_ref(ref, 'HEAD')
    repos.local.cmd(['git', 'worktree', 'add', 'submissions/gh-11', 'HEAD'])

    # Simulate a worktree whose initial creation was interrupted
    repos.local.cmd([
        'git', 'worktree', 'lock', '--reason', 'initializing',
        'submissions/gh-11'
    ])
    extra_file_path = os.path.join(
        repos.local.cwd, 'submissions', 'gh-11', 'extra-file'
    )
    with open(extra_file_path, 'w') as handle:
        handle.write('this file is not under version control')

    # Simulate closing pull requests
    repos.remote.delete_ref('refs/prs-open/gh-11')

    subprocess.check_call(subject, cwd=repos.local.cwd)

    expected = set(('submissions/gh-23',))
    assert expected == set(repos.local.worktrees())
