# Makefile for releasing poginfo
#
# The release version is controlled from pkg/version

TAG?=latest
NAME:=poginfo
DOCKER_REPOSITORY:=jojomomojo
DOCKER_IMAGE_NAME:=$(DOCKER_REPOSITORY)/$(NAME)
GIT_COMMIT:=$(shell git describe --dirty --always)
VERSION:=$(shell grep 'VERSION' pkg/version/version.go | awk '{ print $$4 }' | tr -d '"')
EXTRA_RUN_ARGS?=

.PHONY: test

SHELL := /bin/bash

menu:
	@perl -ne 'printf("%20s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

run: # Run poginfo
	go run -ldflags "-s -w -X github.com/jojomomojo/poginfo/pkg/version.REVISION=$(GIT_COMMIT)" cmd/poginfo/* \
	--level=debug --grpc-port=9999 --backend-url=https://httpbin.org/status/401 --backend-url=https://httpbin.org/status/500 \
	--ui-logo=https://raw.githubusercontent.com/jojomomojo/poginfo/gh-pages/cuddle_clap.gif $(EXTRA_RUN_ARGS)

test: # Test code
	go test -v -race ./...

build: # Build poginfo, podcli
	GIT_COMMIT=$$(git rev-list -1 HEAD) && CGO_ENABLED=0 go build  -ldflags "-s -w -X github.com/jojomomojo/poginfo/pkg/version.REVISION=$(GIT_COMMIT)" -a -o ./bin/poginfo ./cmd/poginfo/*
	GIT_COMMIT=$$(git rev-list -1 HEAD) && CGO_ENABLED=0 go build  -ldflags "-s -w -X github.com/jojomomojo/poginfo/pkg/version.REVISION=$(GIT_COMMIT)" -a -o ./bin/podcli ./cmd/podcli/*

fmt: # Format code and imports
	gofmt -l -s -w ./
	goimports -l -w ./

build-charts: # Build helm charts
	helm lint charts/*
	helm package charts/*

build-container: # Build container image
	docker build -t $(DOCKER_IMAGE_NAME):$(VERSION) .

build-base: # Build base container image
	docker build -f Dockerfile.base -t $(DOCKER_REPOSITORY)/poginfo-base:latest .

push-base: build-base
	docker push $(DOCKER_REPOSITORY)/poginfo-base:latest

test-container: # Test container
	@docker rm -f poginfo || true
	@docker run -dp 9898:9898 --name=poginfo $(DOCKER_IMAGE_NAME):$(VERSION)
	@docker ps
	@TOKEN=$$(curl -sd 'test' localhost:9898/token | jq -r .token) && \
	curl -sH "Authorization: Bearer $${TOKEN}" localhost:9898/token/validate | grep test

push-container: # Push to Docker Hub and Quay
	docker tag $(DOCKER_IMAGE_NAME):$(VERSION) $(DOCKER_IMAGE_NAME):latest
	docker push $(DOCKER_IMAGE_NAME):$(VERSION)
	docker push $(DOCKER_IMAGE_NAME):latest
	docker tag $(DOCKER_IMAGE_NAME):$(VERSION) quay.io/$(DOCKER_IMAGE_NAME):$(VERSION)
	docker tag $(DOCKER_IMAGE_NAME):$(VERSION) quay.io/$(DOCKER_IMAGE_NAME):latest
	docker push quay.io/$(DOCKER_IMAGE_NAME):$(VERSION)
	docker push quay.io/$(DOCKER_IMAGE_NAME):latest

version-set: # Set version in code, deployment, manifests
	@next="$(TAG)" && \
	current="$(VERSION)" && \
	sed -i '' "s/$$current/$$next/g" pkg/version/version.go && \
	sed -i '' "s/tag: $$current/tag: $$next/g" charts/poginfo/values.yaml && \
	sed -i '' "s/tag: $$current/tag: $$next/g" charts/poginfo/values-prod.yaml && \
	sed -i '' "s/appVersion: $$current/appVersion: $$next/g" charts/poginfo/Chart.yaml && \
	sed -i '' "s/version: $$current/version: $$next/g" charts/poginfo/Chart.yaml && \
	sed -i '' "s/poginfo:$$current/poginfo:$$next/g" kustomize/deployment.yaml && \
	sed -i '' "s/poginfo:$$current/poginfo:$$next/g" deploy/webapp/frontend/deployment.yaml && \
	sed -i '' "s/poginfo:$$current/poginfo:$$next/g" deploy/webapp/backend/deployment.yaml && \
	sed -i '' "s/poginfo:$$current/poginfo:$$next/g" deploy/bases/frontend/deployment.yaml && \
	sed -i '' "s/poginfo:$$current/poginfo:$$next/g" deploy/bases/backend/deployment.yaml && \
	echo "Version $$next set in code, deployment, chart and kustomize"

release: # Tag and push
	git tag $(VERSION)
	git push origin $(VERSION)

swagger: # Initialize swagger
	go get github.com/swaggo/swag/cmd/swag
	cd pkg/api && $$(go env GOPATH)/bin/swag init -g server.go
