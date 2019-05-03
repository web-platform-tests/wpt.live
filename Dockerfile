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
    tzdata

ENV TZ "UTC"
RUN echo "${TZ}" > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /root/wpt
RUN git init .

RUN git remote add origin https://github.com/web-platform-tests/wpt.git

COPY src/wpt-config.json /root/wpt-config.json

CMD git pull origin master --depth 1 --no-tags && \
  python ./wpt serve --config ../wpt-config.json
