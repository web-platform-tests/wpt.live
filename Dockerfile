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

VOLUME /root/wpt
COPY src/wpt-config.json /root/wpt-config.json
WORKDIR /root/wpt

CMD ["python", "./wpt", "serve", "--config", "./../wpt-config.json"]
