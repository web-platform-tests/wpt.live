FROM python:2.7-slim
RUN mkdir /mnt/web-platform-tests
RUN mkdir -p /etc/letsencrypt/live/web-platform-tests.live
VOLUME /mnt/web-platform-tests
VOLUME /mnt/keys
WORKDIR /mnt/web-platform-tests
EXPOSE 80
EXPOSE 443
CMD python wpt make-hosts-file | tee -a /etc/hosts && python wpt serve
