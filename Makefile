HOST=gcr.io
PROJECT_ID=wptdashboard

.PHONY: test
test:
	terraform fmt --check
	flake8 src test
	pytest test

.PHONY: cert-renewer wpt-server-tot wpt-server-submissions
cert-renewer wpt-server-tot wpt-server-submissions:
	docker build \
		--tag web-platform-tests-live-$@ \
		--file $@.Dockerfile \
		.

run-%: %
	docker run \
		--rm \
		--interactive \
		--tty \
		--publish 80:80 \
		--publish 8000:8000 \
		--publish 443:443 \
		--env WPT_HOST \
		--env WPT_ALT_HOST \
		--env WPT_BUCKET \
		web-platform-tests-live-$*

google-cloud-platform-credentials.json:
	@echo To publish images, the file $@ must be present in the root of >&2
	@echo this repository. >&2
	@exit 1

.PHONY: login
login: google-cloud-platform-credentials.json
	cat $< | \
		docker login -u _json_key --password-stdin $(HOST)

publish-%: % login
	docker tag web-platform-tests-live-$* \
		$(HOST)/$(PROJECT_ID)/web-platform-tests-live-$*
	docker push $(HOST)/$(PROJECT_ID)/web-platform-tests-live-$*
