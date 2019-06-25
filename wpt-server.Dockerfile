FROM ubuntu:18.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get -qqy update \
  && apt-get -qqy install \
    curl \
    gettext-base \
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
COPY src/wpt-config.json.template /root/wpt-config.json.template

WORKDIR /root/wpt
ENV WPT_HOST=web-platform-tests.live \
  WPT_ALT_HOST=not-web-platform-tests.live \
  WPT_BUCKET=web-platform-tests-live

CMD git pull origin master --depth 1 --no-tags && \
  envsubst < ../wpt-config.json.template > wpt-config.json && \
  wrapper.py \
    --sentinel "fetch-certs.py --bucket $WPT_BUCKET --period 3600" \
    --sentinel 'fetch-wpt.py --remote origin --branch master --period 60' \
    -- \
      ./wpt serve --config ../wpt-config.json
