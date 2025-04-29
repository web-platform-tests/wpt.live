HOST=gcr.io
PROJECT_ID=wpt-live-app

.PHONY: cert-renewer wpt-server-tot
cert-renewer wpt-server-tot:
	docker build \
		--tag wpt-live-$@ \
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
		wpt-live-$*

.PHONY: login
login:
	 yes | gcloud auth configure-docker

publish-%: % login
	docker tag wpt-live-$* $(HOST)/$(PROJECT_ID)/wpt-live-$*
	docker push $(HOST)/$(PROJECT_ID)/wpt-live-$*
