HOST=gcr.io
PROJECT_ID=wptdashboard

.PHONY: build-tls-sync
build-tls-sync:
	docker build \
		--tag web-platform-tests-live-tls-sync \
		--file Dockerfile-tls-sync \
		.

run-tls-sync: build-tls-sync
	docker run \
		--rm \
		--interactive \
		--tty \
		web-platform-tests-live-tls-sync

deploy:
	docker build -t web-platform-tests-live .
	docker run \
		--rm \
		--interactive \
		--tty \
		--publish 80:80 \
		--publish 8000:8000 \
		--publish 443:443 \
		--volume $(shell pwd)/../wpt:/root/wpt \
		web-platform-tests-live

google-cloud-platform-credentials.json:
	@echo You need this. >&2
	@exit 1

.PHONY: login
login: google-cloud-platform-credentials.json
	cat $< | \
		docker login -u _json_key --password-stdin $(HOST)

publish:
	docker tag web-platform-tests-live \
		$(HOST)/$(PROJECT_ID)/web-platform-tests-live
	docker push $(HOST)/$(PROJECT_ID)/web-platform-tests-live
