#!/usr/bin/env bash
set -e

function parse_git_hash() {
  git rev-parse --short HEAD 2> /dev/null || echo 0000000
}

if [ ! -d .git ] ; then
  git init
  git remote add orign https://github.com/web-platform-tests/wpt.git
fi

GIT_HEAD=$(parse_git_hash)

git pull --quiet origin master

GIT_NEW_HEAD=$(parse_git_hash)

if [ "$GIT_HEAD" != "$GIT_NEW_HEAD" ]
then
    echo "HEAD changed (${GIT_HEAD} -> ${GIT_NEW_HEAD}). Restarting service."
    systemctl restart wpt
else
    echo "HEAD unchanged (${GIT_HEAD}). Taking no action."
fi

