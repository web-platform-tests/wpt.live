FROM python:2.7-slim

RUN mkdir /web-platform-tests
WORKDIR /web-platform-tests

ADD . /web-platform-tests/
RUN echo '{"ports":{"http":[80,"auto"],"https":[443]},"bind_address":false}' > /web-platform-tests/config.json

EXPOSE 80
EXPOSE 443

CMD [ "python", "wpt", "serve" ]

