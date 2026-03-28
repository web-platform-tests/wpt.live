FROM ubuntu:22.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

# Search for the packages with the "jammy" distribution (aka 22.04) selected on https://packages.ubuntu.com/.
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
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    supervisor \
    tzdata \
    libcap2-bin && \
  sed -i 's/chmod=0700/chmod=0770\nchown=root:wpt-sync/' /etc/supervisor/supervisord.conf && \
  setcap 'cap_net_bind_service=+ep' /usr/bin/python3.10

RUN useradd -ms /bin/bash -u 1000 wpt-server && \
    useradd -ms /bin/bash -u 1001 wpt-sync && \
    usermod -aG wpt-sync wpt-server


# For Google Cloud, look under https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages
# https://cloud.google.com/storage/docs/gsutil_install
# Copy the "Docker Tip" instructions from gsutil_install link and then pin the version
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && apt-get update -y && apt-get install google-cloud-cli=526.0.1-0 -y



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
  -keyout /home/wpt-sync/privkey.pem \
  -out /home/wpt-sync/fullchain.pem

COPY src/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV GIT_WORK_TREE=/home/wpt-sync/wpt
ENV GIT_DIR=/home/wpt-sync/wpt-git
RUN mkdir -p /home/wpt-sync/wpt && \
  mkdir -p /home/wpt-sync/wpt-git && \
  cd /home/wpt-sync/wpt && \
  git init . && \
  git remote add origin https://github.com/web-platform-tests/wpt.git && \
  chown -R wpt-sync:wpt-sync /home/wpt-sync && \
  chmod a+rx /home/wpt-sync /home/wpt-sync/wpt /home/wpt-sync/wpt-git && \
  chmod g+w /home/wpt-sync/wpt

COPY src/fetch-certs.py src/fetch-wpt.py /usr/local/bin/
COPY src/wpt-config.json.template /home/wpt-sync/wpt-config.json.template
RUN chown wpt-sync:wpt-sync /home/wpt-sync/wpt-config.json.template

WORKDIR /home/wpt-sync/wpt
ENV WPT_HOST=wpt.live \
  WPT_ALT_HOST=not-wpt.live \
  WPT_BUCKET=wpt-live

CMD ["/usr/bin/supervisord"]
