FROM ubuntu:22.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

# Pin the versions for repeatable builds
# For ubuntu package versions, go to https://packages.ubuntu.com/
#   Search for the package with the "jammy" distribution (aka 22.04) selected.
# For Google Cloud, look under https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages
RUN \
  apt-get -qqy update && \
  apt-get -qqy install \
    apt-transport-https=2.4.6 \
    ca-certificates=20211016 \
    curl=7.81.0-1ubuntu1.3 \
    gettext-base=0.21-4ubuntu4 \
    git=1:2.34.1-1ubuntu1.4 \
    gnupg=2.2.27-3ubuntu2.1 \
    locales=2.35-0ubuntu3.1 \
    python3=3.10.4-0ubuntu2 \
    python3-dev=3.10.4-0ubuntu2 \
    python3-pip=22.0.2+dfsg-1 \
    python3-venv=3.10.4-0ubuntu2 \
    supervisor=4.2.1-1ubuntu1 \
    tzdata=2022a-0ubuntu1 && \
  # https://cloud.google.com/storage/docs/gsutil_install
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    tee /usr/share/keyrings/cloud.google.gpg && \
  apt-get -qqy update && \
  apt-get -qqy install \
    google-cloud-cli=396.0.0-0 && \
  rm -rf /var/lib/apt/lists/* && apt-get clean


ENV TZ "UTC"
RUN echo "${TZ}" > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

# Generate and set the locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en
RUN dpkg-reconfigure --frontend=noninteractive locales

# Generate a self-signed TLS certificate so that the WPT server can be started
# prior to the initial retrieval of the latest legitimate certificate.
RUN openssl req \
  -x509 \
  -nodes \
  -subj '/CN=example.com' \
  -days 1 \
  -newkey rsa:4096 -sha256 \
  -keyout /root/privkey.pem \
  -out /root/fullchain.pem

COPY src/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir /root/wpt && \
  cd /root/wpt && \
  git init . && \
  git remote add origin https://github.com/web-platform-tests/wpt.git

COPY src/fetch-certs.py src/fetch-wpt.py /usr/local/bin/
COPY src/wpt-config.json.template /root/wpt-config.json.template

WORKDIR /root/wpt
ENV WPT_HOST=wpt.live \
  WPT_ALT_HOST=not-wpt.live \
  WPT_BUCKET=wpt-live

CMD ["/usr/bin/supervisord"]
