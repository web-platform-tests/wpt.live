#!/bin/bash

# Although WPT server instances need only the TLS certificates provided by the
# Let's Encrypt servers, this utility saves and fetches the complete Certbot
# configuration. This allows new deployments to initialize without requesting
# new certificates.
#
# > [...] with Certbot, you can back up and migrate the /etc/letsencrypt
# > directory (including symbolic link structure). Then Certbot would see the
# > old certificates and configuration and continue using them, assuming that
# > the configuration of the server is otherwise similar enough that whatever
# > authentication method was used to prove control of the domain also works in
# > the same way on the new server.
#
# https://community.letsencrypt.org/t/how-to-backup-and-restore-lets-encrypt-ubuntu-server/39617
#
# Let's Encrypt offers generous rate limits, so every new deployment could
# simply request a new certificate. However, if consecutive deployments were to
# exceed the rate limit (e.g. in response to some pathological failure), the
# system could not recover for the duration of the cool-down period.

set -euo pipefail

action=${1:-_}
name=${2:-_}
host=${3:-_}

if [ \
    \( ${action} != 'save' -a ${action} != 'fetch' \) -o \
    ${name} = '_' -o \
    ${host} = '_' ]; then
  script_name=$(basename ${0})

  cat <<HELP
Usage: ${script_name} [ACTION] [NAME] [HOST]
Retrieve Let's Encrypt certificate information from a remote storage location
or save the information available locally to a remote storage location.

- ACTION - one of "save" or "fetch"
- NAME - name of a Google Cloud Storage bucket
- HOST - name of the primary host for the certificate
HELP
  exit 1
fi

tmp=$(mktemp)
trap "rm ${tmp}" EXIT

if [ ${action} = 'save' ]; then
  today=$(date --rfc-3339 date)
  echo Saving certificate for ${today}...

  (cd /etc/letsencrypt && tar cvf ${tmp} .)

  gsutil cp ${tmp} gs://${name}/archive/${today}.tar
  gsutil cp ${tmp} gs://${name}/latest.tar
  gsutil cp \
    /etc/letsencrypt/live/${host}/fullchain.pem \
    /etc/letsencrypt/live/${host}/privkey.pem \
    gs://${name}
else
  echo Fetching certificate...

  if gsutil cp gs://${name}/latest.tar ${tmp}; then
    echo Certificate found. Installing.

    mkdir -p /etc/letsencrypt
    (cd /etc/letsencrypt && tar xvf ${tmp})
  else
    echo No certificate found in cache.
  fi
fi
