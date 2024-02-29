clustername := kind-istio-prometheus

istio_target_arch ?= x86_64
istio_version ?= 1.17.4
istio_download_dir ?= /tmp
istio_root=$(istio_download_dir)/istio-$(istio_version)

make-kind-dir:
	mkdir -p $(HOME)/.kube/kind

#-------------------------------------------------
# Target: Create kind cluster
# ------------------------------------------------

cluster: make-kind-dir cluster-create

cluster-create:
	kind create cluster --name $(clustername) --kubeconfig=$(HOME)/.kube/kind/$(clustername)

#-------------------------------------------------
# Target: Istio install 
# ------------------------------------------------

istio-install:
	$(istio_root)/bin/istioctl --kubeconfig $(HOME)/.kube/kind/$(clustername) install -y -f $(istio_root)/manifests/profiles/minimal.yaml

istio-create-ns:
	kubectl --kubeconfig=$(HOME)/.kube/kind/$(clustername) create ns istio-system

istio-download:
	@echo "Download Istio Version: $(istio_version)"
	cd $(istio_download_dir) && curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$(istio_version) TARGET_ARCH=$(istio_target_arch) sh -

istio: istio-download istio-create-ns istio-install

#-------------------------------------------------
# Target: httpbin install 
# ------------------------------------------------

httpbin:
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) create ns httpbin 
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) label --overwrite namespace httpbin istio-injection=enabled
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f $(istio_root)/samples/httpbin/httpbin.yaml -n httpbin 

#-------------------------------------------------
# Target: Sleep install 
# ------------------------------------------------

sleep:
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) create ns sleep 
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) label --overwrite namespace sleep istio-injection=enabled
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f $(istio_root)/samples/sleep/sleep.yaml -n sleep 

#-------------------------------------------------
# Target: Fortio install 
# ------------------------------------------------

create-fortio-ns:
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) create ns fortio && kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) label ns fortio istio-injection=enabled 

apply-fortio-manifest:
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f $(istio_root)/samples/httpbin/sample-client/fortio-deploy.yaml -n fortio 

deploy-fortio: create-fortio-ns apply-fortio-manifest

#-------------------------------------------------
# Target: prometheus install 
# ------------------------------------------------

prometheus-manifests:
	curl -sL https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.71.2/bundle.yaml | kubectl create -f -
	kubectl wait --for=condition=Ready pods -l  app.kubernetes.io/name=prometheus-operator -n default
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f promethues-sa.yaml -n default
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f cluster-role.yaml -n default
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f cluster-role-binding.yaml -n default
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f promethues.yaml -n default
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f podmonitor.yaml -n default

prometheus: \
	prometheus-manifests

#-------------------------------------------------
# Target: Grafana install 
# ------------------------------------------------

grafana:
	kubectl --kubeconfig $(HOME)/.kube/kind/$(clustername) apply -f $(istio_root)/samples/addons/grafana.yaml

#-------------------------------------------------
# Target: Install 
# ------------------------------------------------

install: \
	cluster \
	istio \
	prometheus \
	grafana \
	httpbin \
	sleep 

#-------------------------------------------------
# Target: Clean 
# ------------------------------------------------

clean:
	kind delete cluster --name $(clustername) 
