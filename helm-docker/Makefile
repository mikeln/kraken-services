DOCKER_REGISTRY := quay.io/samsung_cnct
HELM_REPO       := git@github.com:kubernetes/helm.git

.PHONY: all
all: build push 

.PHONY: build
build: precheck build-helm build-helm-docker

.PHONY: precheck
precheck:
	@if [ -z ${GOPATH} ]; then \
		echo "Make sure your GOPATH is set"; \
		exit 1; \
	fi

	@if [ -z ${GOBIN} ]; then \
		echo "Make sure your GOBIN is set"; \
		exit 1; \
	fi

	@if [ ! -d ${GOPATH}/src/k8s.io/helm ]; then \
		mkdir -p ${GOPATH}/src/k8s.io/helm; \
		git clone ${HELM_REPO} ${GOPATH}/src/k8s.io/helm; \
	else \
		echo "WARNING: ${GOPATH}/src/k8s.io/helm already present. Assuming that it is clean."; \
	fi

.PHONY: build-helm
build-helm:
	cd ${GOPATH}/src/k8s.io/helm; make bootstrap build-cross
	cp ${GOBIN}/linux_amd64/helm .
	cd ${GOPATH}/src/k8s.io/helm; make docker-build
	docker tag gcr.io/kubernetes-helm/tiller:canary ${DOCKER_REGISTRY}/tiller:$$(cd ${GOPATH}/src/k8s.io/helm; git rev-parse HEAD)
	docker tag gcr.io/kubernetes-helm/tiller:canary ${DOCKER_REGISTRY}/tiller:latest

.PHONY: build-helm-docker
build-helm-docker:
	docker build -t ${DOCKER_REGISTRY}/helm:$$(cd ${GOPATH}/src/k8s.io/helm; git rev-parse HEAD) .
	docker tag ${DOCKER_REGISTRY}/helm:$$(cd ${GOPATH}/src/k8s.io/helm; git rev-parse HEAD) ${DOCKER_REGISTRY}/helm:latest

.PHONY: push
push:
	docker push ${DOCKER_REGISTRY}/tiller:$$(cd ${GOPATH}/src/k8s.io/helm; git rev-parse HEAD)
	docker push ${DOCKER_REGISTRY}/tiller:latest
	docker push ${DOCKER_REGISTRY}/helm:$$(cd ${GOPATH}/src/k8s.io/helm; git rev-parse HEAD)
	docker push ${DOCKER_REGISTRY}/helm:latest

.PHONY: clean
clean:
	rm ./helm