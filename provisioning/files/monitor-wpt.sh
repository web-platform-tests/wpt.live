#!/bin/bash

# The WPT server has been observed to intermittently become unresponsive in
# production settings. The application is built on Python's built-in HTTP
# server; since this is not intended for production use, the outages are
# believed to be a result of library code (not application logic). This script
# is designed to minimize the effect of this problem by forcibly restarting the
# server if it is found to be unresponsive.

if [ "$1" != 'http' -a "$1" != 'https' ]; then
  echo Script must be invoked with one argument, either: http or https >&2
  exit 1
fi

# Include a query string to differentiate this diagnostic test from requests
# from external visitors. Include the protocol to account for a deficiency in
# WPT's logging capabilities [1].
#
# [1] https://github.com/web-platform-tests/wpt/pull/13632
url=$1://web-platform-tests.live?internal-monitor-$1
timeout=5

curl --silent --fail ${url} > /dev/null &

curl_pid=$!

sleep $timeout

ps -p $curl_pid > /dev/null

if [ "$?" == '0' ]; then
  echo $url unresponsive after $timeout seconds. Restarting server.
  systemctl restart wpt
  exit
fi

wait $curl_pid

if [ "$?" != '0' ]; then
  echo $url returned an error. Restarting server.
  systemctl restart wpt
  exit
fi

echo $url operating as expected.
