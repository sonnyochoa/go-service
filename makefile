SHELL := /bin/bash

# ==============================================================================
# Testing running system

#
# For testing load on the service.
# hey -m GET -c 100 -n 10000 http://localhost:3000/v1/test

#
# To generate a private/public key PEM file.
# openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:2048
# openssl rsa -pubout -in private.pem -out public.pem

#
# Testing Authetication.
# curl -il http://localhost:3000/v1/test/auth
# curl -il -H "Authorization: Bearer ${TOKEN}" http://localhost:3000/v1/test/auth

#
# expvarmon -ports=":4000" -vars="build,requests,goroutines,errors,panics,mem:memstats.Alloc"
# ==============================================================================

run:
	go run app/services/sales-api/main.go | go run app/tooling/logfmt/main.go

admin:
	go run app/tooling/admin/main.go

# ==============================================================================
# Running tests within the local computer
test:
	go test ./... -count=1
	staticcheck -checks=all ./...

# ==============================================================================
dev.setup.mac.common:
	brew update
	brew tap hashicorp/tap
	brew list kind || brew install kind
	brew list kubectl || brew install kubectl
	brew list kustomize || brew install kustomize
	brew list pgcli || brew install pgcli
	brew list vault || brew install vault

dev.setup.mac.arm64: dev.setup.mac.common
	brew datawire/blackbird/telepresence-arm64 || brew install datawire/blackbird/telepresence-arm64
# ==============================================================================
# Building containers

VERSION := 1.0

all: sales-api

sales-api:
	docker build \
		-f zarf/docker/dockerfile.sales-api \
		-t sales-api-arm64:$(VERSION) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.

# ==============================================================================
# For full Kind v0.17 release notes: https://github.com/kubernetes-sigs/kind/releases/tag/v0.17.0
# Running from within k8s/kind

KIND_CLUSTER := noisesignal-starter-cluster

# kind-up:
# 	kind create cluster \
# 		--image kindest/node:v1.25.3@sha256:f52781bc0d7a19fb6c405c2af83abfeb311f130707a0e219175677e366cc45d1 \
# 		--name $(KIND_CLUSTER) \
# 		--config zarf/k8s/kind/kind-config.yaml
kind-up:
	kind create cluster \
		--image kindest/node:v1.26.0@sha256:691e24bd2417609db7e589e1a479b902d2e209892a10ce375fab60a8407c7352 \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/kind/kind-config.yaml
	kubectl config set-context --current --namespace=sales-system

kind-down:
	kind delete cluster --name $(KIND_CLUSTER)

kind-load:
	cd zarf/k8s/kind/sales-pod; kustomize edit set image sales-api-image=sales-api-arm64:$(VERSION)
	kind load docker-image sales-api-arm64:$(VERSION) --name $(KIND_CLUSTER)

kind-apply:
	kustomize build zarf/k8s/kind/database-pod | kubectl apply -f -
	kubectl wait --namespace=database-system --timeout=300s --for=condition=Available deployment/database-pod
	kustomize build zarf/k8s/kind/sales-pod | kubectl apply -f -

kind-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

kind-status-sales:
	kubectl get pods -o wide --watch 

kind-status-db:
	kubectl get pods -o wide --watch --namespace=database-system

kind-logs:
	kubectl logs -l app=go-sales --all-containers=true -f --tail=100 | go run app/tooling/logfmt/main.go

kind-restart:
	kubectl rollout restart deployment sales-pod

kind-update: all kind-load kind-restart

kind-update-apply: all kind-load kind-apply

kind-describe:
	kubectl describe pod -l app=go-sales


# ==============================================================================
# Modules support
tidy:
	go mod tidy
	go mod vendor
