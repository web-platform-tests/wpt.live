FROM ubuntu:18.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get -qqy update \
  && apt-get -qqy install \
    curl \
    git \
    locales \
    python \
    python-pip \
    python3 \
    tzdata

ENV TZ "UTC"
RUN echo "${TZ}" > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN mkdir /root/wpt && \
  cd /root/wpt && \
  git init . && \
  git remote add origin https://github.com/web-platform-tests/wpt.git

COPY src/fetch-certs.py src/fetch-wpt.py src/wrapper.py /usr/local/bin/
COPY src/wpt-config.json /root/wpt-config.json

WORKDIR /root/wpt

CMD git pull origin master --depth 1 --no-tags && \
  wrapper.py \
    --sentinel 'fetch-certs.py --bucket web-platform-tests-live --period 3600' \
    --sentinel 'fetch-wpt.py --remote origin --branch master --period 60' \
    -- \
      ./wpt serve --config ../wpt-config.json
