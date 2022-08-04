FROM ubuntu:22.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

ENV WPT_HOST=wpt.live \
  WPT_ALT_HOST=not-wpt.live \
  WPT_BUCKET=wpt-live

# Pin the versions for repeatable builds
# For ubuntu package versions, go to https://packages.ubuntu.com/
#   Search for the package with the "jammy" distribution (aka 22.04) selected.
# For Google Cloud, look under https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages
RUN apt-get -qqy update && \
  apt-get -qqy install \
    apt-transport-https=2.4.6 \
    ca-certificates=20211016 \
    curl=7.81.0-1ubuntu1.3 \
    gnupg=2.2.27-3ubuntu2.1 \
    python3=3.10.4-0ubuntu2 \
    python3-dev=3.10.4-0ubuntu2 \
    python3-pip=22.0.2+dfsg-1 && \
  # https://cloud.google.com/storage/docs/gsutil_install
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    tee /usr/share/keyrings/cloud.google.gpg && \
  apt-get -qqy update && \
  apt-get -qqy install \
    google-cloud-cli=396.0.0-0 && \
  rm -rf /var/lib/apt/lists/* && apt-get clean

# Instructions for certbot installation
# https://certbot.eff.org/instructions?ws=other&os=pip
RUN pip install certbot==1.29.0 certbot-dns-google==1.29.0

COPY src/cert-store.sh /usr/local/bin/

# > If you would like to obtain a wildcard certificate from Let’s Encrypt’s
# > ACMEv2 server, you’ll need to include
# >
# >     --server https://acme-v02.api.letsencrypt.org/directory
# >
# > on the command line as well.
#
# https://eff-certbot.readthedocs.io/en/stable/using.html?highlight=wildcard#dns-plugins

CMD bash -c '\
  cert-store.sh fetch ${WPT_BUCKET} ${WPT_HOST}; \
  while true; do \
    certbot certonly \
      -d ${WPT_HOST} \
      -d *.${WPT_HOST} \
      -d ${WPT_ALT_HOST} \
      -d *.${WPT_ALT_HOST} \
      --dns-google \
      --dns-google-propagation-seconds 120 \
      --agree-tos \
      --non-interactive \
      --email infrastructure@bocoup.com \
      --server https://acme-v02.api.letsencrypt.org/directory \
      --deploy-hook "cert-store.sh save ${WPT_BUCKET} ${WPT_HOST}"; \
    sleep $((60 * 60 * 24)); \
  done'
