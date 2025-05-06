FROM ubuntu:22.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

ENV WPT_HOST=wpt.live \
  WPT_ALT_HOST=not-wpt.live \
  WPT_BUCKET=wpt-live

# Pin the versions of python and google cloud cli for repeatable builds
# For ubuntu package versions, go to https://packages.ubuntu.com/
#   Search for the package with the "jammy" distribution (aka 22.04) selected.
RUN apt-get -qqy update && \
  apt-get -qqy install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    python3=3.10.6-1~22.04.1 \
    python3-dev=3.10.6-1~22.04.1 \
    python3-pip=22.0.2+dfsg-1ubuntu0.5
# For Google Cloud, look under https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages
# https://cloud.google.com/storage/docs/gsutil_install
# Copy the "Docker Tip" instructions from gsutil_install link and then pin the version
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && apt-get update -y && apt-get install google-cloud-cli=451.0.1-0 -y

# Instructions for certbot installation
# https://certbot.eff.org/instructions?ws=other&os=pip
RUN pip install acme==1.29.0 certbot==1.29.0 certbot-dns-google==1.29.0

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
  cert-store.sh fetch ${WPT_BUCKET} ${WPT_HOST} && \
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
    --deploy-hook "cert-store.sh save ${WPT_BUCKET} ${WPT_HOST}"'
