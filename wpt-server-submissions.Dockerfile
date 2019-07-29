FROM web-platform-tests-live-wpt-server-tot

COPY src/mirror-pull-requests.sh /usr/local/bin/
COPY src/supervisord-pull-requests.conf /etc/supervisor/conf.d/
