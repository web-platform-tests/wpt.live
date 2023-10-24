FROM ubuntu:22.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

# Pin the versions of python and google cloud cli for repeatable builds
# For ubuntu package versions, go to https://packages.ubuntu.com/
#   Search for the package with the "jammy" distribution (aka 22.04) selected.
RUN \
  apt-get -qqy update && \
  apt-get -qqy install \
    apt-transport-https \
    ca-certificates \
    curl \
    gettext-base \
    git \
    gnupg \
    locales \
    python3=3.10.6-1~22.04 \
    python3-dev=3.10.6-1~22.04 \
    python3-pip=22.0.2+dfsg-1 \
    python3-venv=3.10.6-1~22.04 \
    supervisor \
    tzdata
# For Google Cloud, look under https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages
# https://cloud.google.com/storage/docs/gsutil_install
# Copy the "Docker Tip" instructions from gsutil_install link and then pin the version
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && apt-get update -y && apt-get install google-cloud-cli=451.0.1-0 -y



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
