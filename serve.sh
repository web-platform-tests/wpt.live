#!/bin/bash

green_http=8765
green_https=8766

blue_http=9765
blue_https=9766

rule=$(sudo iptables -t nat -L OUTPUT --line-numbers | grep -E "$green_http|$blue_http")
old_http=$(echo $rule | grep -E --only-matching "$green_http|$blue_http")
index=$(echo $rule | awk '{ print $1 }')

if [ "$old_http" = "$green_http" ]; then
  new_name=blue
  old_name=green
  new_http=$blue_http
  hew_https=$bllue_https
else
  new_name=green
  old_name=blue
  new_http=$green_http
  new_https=$green_https
fi

sudo docker build wpt .

sudo docker run \
  --detach \
  --mount type=bind,source=/etc/letsencrypt/live/web-platform-tests.live,target=/etc/letsencrypt/live/web-platform-tests.live \
  --mount type=bind,source=/root/web-platform-tests,target=/mnt/web-platform-tests \
  --rm \
  --publish $new_http:80 \
  --publish $new_https:443 \
  --name $new_name \
  wpt

# Wait for container to be ready
while ! curl --quiet --fail localhost:$new_http ; do
  sleep 1
done

# Switch container into place
sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 80 -j REDIRECT --to-port $new_http
sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 443 -j REDIRECT --to-port $new_https

# Clean up outdated container
if [ -n "$old_name" ]; then
  sudo iptables -t nat -D OUTPUT $index
  sudo docker rm --force $old_name
fi

# Ensure script does not terminate until container stops
sudo docker logs --follow $new_name > /dev/null
