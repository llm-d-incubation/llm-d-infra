# llm-d-infra Quick Start - Step by step

Getting started with llm-d-infra through step-by-step procedures.

This guide will walk you through the steps to install and deploy llm-d-infra on a Kubernetes cluster, with the place of customization.

## Client Configuration

### Required tools

Following prerequisite are required for the installer to work.

- [Helm – quick-start install](https://helm.sh/docs/intro/install/)
- [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Required credentials and configuration

- [HuggingFace HF_TOKEN](https://huggingface.co/docs/hub/en/security-tokens)

> Depending on which model you use, you have to visit Hugging Face and
> accept the usage terms to pull this with your HF token if you have not already done so.

### Target Platform

Since the llm-d-infra is based on helm charts, llm-d-infra can be deployed on a variety of Kubernetes platforms. As more platforms are supported, this installation procedure will be updated to support them.

## llm-d-infra Installation

This document instruct you the totally following 4 steps to deploy llm-d-infra.

1. Installing GAIE Kubernetes infrastructure
1. Installing Network stack
1. Creating HF token secret
1. Installing llm-d-infra

Before proceeding with the installation, ensure you have completed the prerequisites and are able to issue kubectl commands to your cluster by configuring your ~/.kube/config file.

### 1. Installing GAIE Kubernetes infrastructure

Apply CRDs for Gateway API.

```bash
kubectl apply -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gateway-api
```

Then, Apply CRDs for Gateway API Inference Extension.

```bash
kubectl apply -k https://github.com/llm-d/llm-d-inference-scheduler/deploy/components/crds-gie
```

### 2. Installing Network stack

Currently you can choose the network stack from either [istio](https://istio.io/) or [kgateway](https://kgateway.dev/).

Select the appropriate option for your environment.

#### Installing istio

To begin with, export the environmental variables.

Before doing this, please check the appropriate hub and tag from [the istio installation script](https://github.com/llm-d-incubation/llm-d-infra/blob/main/chart-dependencies/istio/install.sh).

```bash
export TAG=1.27-alpha.0551127f00634403cddd4634567e65a8ecc499a7
export HUB=gcr.io/istio-testing
```

Then deploy istio-base.

```bash
helm upgrade -i istio-base oci://$HUB/charts/base --version $TAG -n istio-system --create-namespace
```

After that, deploy istiod.

```bash
helm upgrade -i istiod oci://$HUB/charts/istiod --version $TAG -n istio-system --set tag=$TAG --set hub=$HUB --wait
```

The resources are created as follows:

```bash
kubectl get pods,svc -n istio-system
```

```bash
NAME                         READY   STATUS    RESTARTS   AGE
pod/istiod-774dfd9b6-8jrjr   1/1     Running   0          41s

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                 AGE
service/istiod   ClusterIP   [Cluster IP]    <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   41s
```

You can also find GatewayClass is created:

```bash
kubectl get gc
```

```bash
NAME           CONTROLLER                    ACCEPTED   AGE
istio          istio.io/gateway-controller   True       39s
istio-remote   istio.io/unmanaged-gateway    True       39s
```

#### Installing kgateway

Apply the kgateway CRDs.

```bash
KGTW_VERSION="v2.0.4"
helm upgrade -i \
  --namespace kgateway-system \
  --create-namespace \
  --version "${KGTW_VERSION}" \
  kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds
```

After that, deploy kgateway.

```bash
helm upgrade -i \
  --namespace kgateway-system \
  --create-namespace \
  --version "${KGTW_VERSION}" \
  --set inferenceExtension.enabled=true \
  --set securityContext.allowPrivilegeEscalation=false \
  --set securityContext.capabilities.drop={ALL} \
  --set podSecurityContext.seccompProfile.type=RuntimeDefault \
  --set podSecurityContext.runAsNonRoot=true \
  kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway
```

Wait for the kgateway rollout to complete:

```bash
kubectl rollout status deploy/kgateway -n kgateway-system
```

The resources are created as follows:

```bash
kubectl get pods,svc -n kgateway-system
NAME                           READY   STATUS    RESTARTS   AGE
pod/kgateway-ddbb7668c-v96kw   1/1     Running   0          114s

NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kgateway   ClusterIP   [Cluster IP]    <none>        9977/TCP   114s
```

You can also find GatewayClass is created:

```bash
kubectl get gc
```

```bash
NAME                CONTROLLER                    ACCEPTED   AGE
kgateway            kgateway.dev/kgateway         True       25s
kgateway-waypoint   kgateway.dev/kgateway         True       25s
```

### 3. Creating HF token secret

Create a namespace to deploy llm-d-infra.

***If you follow some [examples](./examples) after this installation, you have to change the namespace name according to the example you'll work on as follows.***

- [inference-scheduling](./examples/inference-scheduling): llm-d-inference-scheduling
- [pd-disaggregation](./examples/pd-disaggregation): llm-d-pd
- [precise-prefix-cache-aware](./examples/precise-prefix-cache-aware): llm-d-wide-ep
- [llm-d-simulator](./examples/sim): llm-d-sim

```bash
export NAMESPACE="llm-d"
kubectl create ns "${NAMESPACE}"
```

Then create a secret to clone the models from HuggingFace.

```bash
export HF_TOKEN="<HF Token>"
kubectl create secret generic llm-d-hf-token \
  --namespace "${NAMESPACE}" \
  --from-literal=HF_TOKEN="${HF_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -n "${NAMESPACE}" -f -
```

### 4. Installing llm-d-infra

Clone the llm-d-infra repository and change directory.

```bash
git clone https://github.com/llm-d-incubation/llm-d-infra.git
cd llm-d-infra/charts/llm-d-infra
```

Resolve the helm package's dependencies.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency build .
```

We have everything we need to deploy llm-d-infra.

***Important: The installation command and its options differ depending on the Network Stack selected in step 2.***

#### with istio

```bash
helm upgrade -i llm-d-infra . --namespace "${NAMESPACE}" \
  --values ./values.yaml \
  --set gateway.gatewayClassName=istio
```

#### with kgateway

```bash
helm upgrade -i llm-d-infra . --namespace "${NAMESPACE}" \
  --values ./values.yaml \
  --set gateway.gatewayClassName=kgateway \
  --set gateway.gatewayParameters.proxyUID=0
```

Service is created as LoadBalancer type.

If you want to change Service type, then please add the `serviceType` option like `--set gateway.serviceType=NodePort`.

## Validation

llm-d-infra resources are created as below.

### istio

```bash
kubectl get pods,svc,gateway -n llm-d
```

```bash
NAME                                                      READY   STATUS    RESTARTS   AGE
pod/llm-d-infra-inference-gateway-istio-d5959b668-qrc2x   1/1     Running   0          44s

NAME                                          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                        AGE
service/llm-d-infra-inference-gateway-istio   NodePort   [Cluster IP]    <none>        15021:30108/TCP,80:32468/TCP   44s

NAME                                                              CLASS   ADDRESS                                                       PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/llm-d-infra-inference-gateway   istio   llm-d-infra-inference-gateway-istio.llm-d.svc.cluster.local   True         44s
```

### kgateway

```bash
kubectl get pods,svc,gateway -n llm-d
```

```bash
NAME                                                READY   STATUS    RESTARTS   AGE
pod/llm-d-infra-inference-gateway-947558945-8zfwq   1/1     Running   0          6s

NAME                                    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/llm-d-infra-inference-gateway   NodePort   [Cluster IP]    <none>        80:31644/TCP   6s

NAME                                                              CLASS      ADDRESS          PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/llm-d-infra-inference-gateway   kgateway   [IP Address]     True         6s
```
