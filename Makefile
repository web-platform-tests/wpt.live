deploy:
	docker build -t web-platform-tests-live .
	docker run --rm -it web-platform-tests-live

provisioning/startup.sh: provisioning/create-startup.sh
	cd provisioning && \
		./create-startup.sh > startup.sh

google-cloud-platform-credentials.json:
	@echo You need this. >&2
	@exit 1

gcp-image: google-cloud-platform-credentials.json provisioning/startup.sh
	echo okay
	#packer build \
	#	--only googlecompute \
	#	--var project_id=wptdashboard \
	#	--var timestamp=$(shell date --iso-8601=seconds) \
	#	--var revision=$(shell git rev-parse --short HEAD) \
	#	provisioning/packer.conf
