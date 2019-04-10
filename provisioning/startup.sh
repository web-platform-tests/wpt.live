#!/bin/bash

mkdir /var/www-data
chown www-data:www-data /var/www-data

apt-get update
apt-get install --yes docker.io

# Configure Docker to fetch images from gcloud's image repository
gcloud auth configure-docker

# The following command correctly updates the `.docker/config.json` file by
# inserts the expected authentication data. However, it is deprecated. sudo
# gcloud docker -- pull gcr.io/wptdashboard/web-platform-tests-live

# This command does *not* update the configuration file correctly:
gcloud auth configure-docker
sudo docker pull gcr.io/wptdashboard/web-platform-tests-live

# TODO: Figure that out.

docker run \
	--detach \
	--volume /var/www-data:/var/www-data \
	--publish 80:80 \
	--publish 443:443 \
	--name wpt-serve \
	wpt-serve

docker run \
	--detach \
	--volume /var/www-data:/var/www-data \
	--name wpt-cert \
	wpt-cert

docker run \
	--detach \
	--volume /var/www-data:/var/www-data \
	--volume /run/docker.sock:/run/docker.sock \
	--name wpt-sync \
	wpt-sync
