HOST=gcr.io
PROJECT_ID=wptdashboard

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

gcp-image: google-cloud-platform-credentials.json provisioning/configure-machine-image.sh
	cd provisioning && \
		packer build \
			--only googlecompute \
			--var project_id=wptdashboard \
			--var timestamp=$(shell date --iso-8601=seconds) \
			--var revision=$(shell git rev-parse --short HEAD) \
			packer.conf

.PHONY: login
login: google-cloud-platform-credentials.json
	cat $< | \
		docker login -u _json_key --password-stdin $(HOST)

publish:
	docker tag web-platform-tests-live \
		$(HOST)/$(PROJECT_ID)/web-platform-tests-live
	docker push $(HOST)/$(PROJECT_ID)/web-platform-tests-live
