#!/usr/bin/env bash
set -e

cd /root/web-platform-tests/

function parse_git_hash() {
  git rev-parse --short HEAD 2> /dev/null
}

GIT_HEAD=$(parse_git_hash)

git pull origin master

GIT_NEW_HEAD=$(parse_git_hash)


if [ "$GIT_HEAD" != "$GIT_NEW_HEAD" ]
then
    echo "web-platform-tests HEAD is now ${GIT_NEW_HEAD} restarting wpt service"
    systemctl restart wpt
fi

