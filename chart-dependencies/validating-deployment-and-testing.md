# Tracking deliver goals and feature completion

The goal of this document is to provide context on what a successful install looks like, as well as briefly touch on how we can test it.

## Deployment

### Kgateway-system (kgateway-control-plane)

```bash
$ oc get deployments -n kgateway-system
NAME       READY   UP-TO-DATE   AVAILABLE
kgateway   1/1     1            1
```

There should be no error logs in the `kgateway` pod. If there is a non-correct `proxyUID` workaround for OCP and a gateway submitted,
you will see logs there. This, in combination with there not being a pod from the deployment of the gateway in the namespace in which
`llm-d` is deployed. If this part is not situated you will not get a valid pod from the deployment as a child resource of the `gateway`.

### Istio

```bash
$ oc get deployments -n istio-system
NAME     READY   UP-TO-DATE   AVAILABLE
istiod   1/1     1            1
```

Similar to the kGateway setup, Istio can be verified by looking into the `istio-system` namespace. There should be no error logs in the `istiod` pod.

### LLM-D namespace

#### Deployments

With a successful deployment you will have the following deployments and pods:

```bash
$ oc get deployments -n llm-d
NAME                                         READY   AVAILABLE
inference-gateway                            1/1     1
llama-32-3b-instruct-model-service-decode    2/2     1
llama-32-3b-instruct-model-service-prefill   2/2     1
redis                                        1/1     1
llm-d-inference-gateway-endpoint-picker      1/1     1
llm-d-modelservice                           1/1     1
```

#### Services

Services:

```bash
$ oc get services -n llm-d
NAME                        TYPE        EXTERNAL-IP   PORT(S)
decoder-svc-model-service   ClusterIP   <none>        8000/TCP,55555/TCP
epp-llama-32-3b-instruct    NodePort    <none>        9002:30209/TCP,9003:32652/TCP,9090:31864/TCP
inference-gateway           NodePort    <none>        80:30703/TCP
prefill-svc-model-service   ClusterIP   <none>        55555/TCP,8000/TCP
redis                       ClusterIP   <none>        8100/TCP
llm-d-modelservice          ClusterIP   <none>        8443/TCP
```

#### Gateway

Gateway:

```bash
$ kubectl get gateway
NAME                CLASS      ADDRESS          PROGRAMMED
inference-gateway   kgateway   172.30.138.173   True
```

Your Gateway should look something as follows:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: inference-gateway
  namespace: e2e-helm
spec:
  gatewayClassName: kgateway
  infrastructure:
    parametersRef:
      group: gateway.kgateway.dev
      kind: GatewayParameters
      name: custom-gw-params
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: default
    port: 80
    protocol: HTTP
status:
  addresses:
  - type: Hostname
    value: aca77f0e381ba47549ede7196278d814-955040258.us-east-1.elb.amazonaws.com
  listeners:
  - attachedRoutes: 1
    conditions:
    - lastTransitionTime: "2025-04-30T23:39:29Z"
      message: ""
      observedGeneration: 1
      reason: Accepted
      status: "True"
      type: Accepted
    - lastTransitionTime: "2025-04-30T23:39:29Z"
      message: ""
      observedGeneration: 1
      reason: NoConflicts
      status: "False"
      type: Conflicted
    - lastTransitionTime: "2025-04-30T23:39:29Z"
      message: ""
      observedGeneration: 1
      reason: ResolvedRefs
      status: "True"
      type: ResolvedRefs
    - lastTransitionTime: "2025-04-30T23:39:29Z"
      message: ""
      observedGeneration: 1
      reason: Programmed
      status: "True"
      type: Programmed
    name: default
    supportedKinds:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
```

Your gateway will vary based on the value of `.Values.inferenceGateway.gateway.service.type`. If you use `clusterIP` you will have an internal
address for the `gateway` `hostname` that will only be hittable within the cluster or with a port-forward. Particularly the `status` section of
the gateway is important, make sure it has, and address, an attached route, and that the route has been `Accepted`, `Programmed`, `ResolvedRefs`,
and `NoConflicts`.

#### GatewayParameters

```bash
$ kubectl get gatewayparameters custom-gw-params  -o yaml
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayParameters
metadata:
  name: custom-gw-params
spec:
  kube:
    envoyContainer:
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 1000880001
        seccompProfile:
          type: RuntimeDefault
    podTemplate:
      extraLabels:
        gateway: custom
    sdsContainer:
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsUser: 1000880001
        seccompProfile:
          type: RuntimeDefault
    service:
      extraLabels:
        gateway: custom
      type: LoadBalancer
```

The `service.type` will affect gateway above. The `runAsUser` will field will only be if running on OCP.

#### InferencePool

An `inferencepool` based off your selected model:

```bash
$ kubectl get inferencepool vllm-llama3-3b-instruct -o yaml
apiVersion: inference.networking.x-k8s.io/v1alpha2
kind: InferencePool
metadata:
  name: vllm-llama3-3b-instruct
spec:
  extensionRef:
    failureMode: FailClose
    group: ""
    kind: Service
    name: epp-llama-32-3b-instruct
  selector:
    llm-d.ai/inferenceServing: "true"
    llm-d.ai/model: llama-3.2-3b-instruct
  targetPortNumber: 8000
```

This `inferencepool` needs the `llm-d.ai/model` and `llm-d.ai/inferencingServing` selector, that is backed against the service of your `endpoint-picker`.
This inferencepool is based off the `llama-3.2-3b-instruct` model

#### httpRoute

```bash
$ kubectl get httpRoute inference-route -o yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: inference-route
spec:
  parentRefs:
  - name: inference-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - group: inference.networking.x-k8s.io
          kind: InferencePool
          name: vllm-llama3-3b-instruct
          port: 8000
```

The `httpRoute` should have its `parentRefs[0].name` reference the name of your `gateway`, in this case `inference-gateway`. Additionally, its `backendRefs`
should reference your `inferencepool`, and its `port` value should match the `targetPort` of the `inferencepool`.

#### Modelservice

## Testing

Once the stack has been deployed and you have verified the relevant pieces we can begin testing.

### Testing directly through precode pod

1. curl from decode pod:

```bash
REPO_ROOT=$(realpath $(git rev-parse --show-toplevel))
NAMESPACE=${NAMESPACE:="demo-ns"} # whats defaulted for demo install
DECODE_POD_NAME=$(kubectl get pod -n ${NAMESPACE} | grep "decode" | head -n 1 | awk '{print $1}')
LMCACHE_CONTAINER_NAME=$(cat "${REPO_ROOT}/charts/llm-d-infra/values.yaml" | yq .vllm.name)-decode # how its calculated in templates

# Workaround for pretty print
INFERENCE_REQUEST=$(kubectl exec -n "${NAMESPACE}" "${DECODE_POD_NAME}" -c "${LMCACHE_CONTAINER_NAME}" -- /bin/sh -c '
  curl -sS http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -H "x-prefiller-url: prefill-svc-model-service.'${NAMESPACE}'.svc.cluster.local:8000" \
    -d '"'"'{
      "model": "/cache/models/meta-llama/Llama-3.2-3B-Instruct",
      "prompt": "this is a new prompt",
      "max_tokens": 50,
      "temperature": 0
    }'"'"' | base64
')
echo "$INFERENCE_REQUEST" | base64 --decode | jq
```

This proves: inferencing pod comes online, and is able to support inferencing requests. It also proves the llm-d proxy container is working, because
in this example were `curl`ing against `8000` where the `vLLM` server runs on `8001` by default.

### Testing through gateway

If the stack is configured correctly we should be able to make requests against the gateway directly. First lets see the models available to us:

```bash
curl http://${GATEWAY_ADDRESS}/v1/models \
  -H "Content-Type: application/json" | jq
```

And next lets send an inferencing request to our model:

```bash
GATEWAY_ADDRESS=$(kubectl get gateway | tail -n 1 | awk '{print $3}')
curl http://${GATEWAY_ADDRESS}/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.2-3B-Instruct",
    "prompt": "this is a new prompt",
    "max_tokens": 50,
    "temperature": 0
  }' | jq
```

If you are getting 404 errors, your path is most likely wrong. If you are getting 503 errors, either `curl` command is probably not formatted properly,
the `endpoint-picker` is extremely strict on allowed `curl` formatting. It is **highly** suggested you start from our template above and swap in your model
and other inferencing paramateres.

What does this example prove? This shows that your services are connected up properly. The organization for the network layer of sending requests through
the gateway is essentially an "end-to-end" test. A successful inferencing request here means:

- Your `gateway` was successfully submitted against the `kgateway` controller, which should spin both a `deployment`, and a `service` that picks up the child
pod of this deployment.
  - A `gatewayParameters` applied to the gateway, in which the `gateway` service type can be dictated
- You have an `httpRoute` that was accepted against your `gateway`, and your `httpRoute` is backed by an `inferencepool`
- You have a `inferencemodel` owned by your `modelservice` CR, with a parent `poolRef` to the `inferencepool`
- An `deployment` of the `endpoint-picker` (which should spin a `pod`) and a corresponding `service`.
  - This `endpoint` picker deployment will specify the `inferencepool` it is watching
- A `modelservice` CR for a given `inferencepool` / model that creates P/D deployments

So in total traversing through the network stack:

Request --> gateway deployment / gateway service --> httpRoute --> `inferencepool` --> epp / epp service --> selects a pod for inference

- the Epp is able to select inferencing pod by matching `llm-d.ai/model` label on the deployments that are children of the `modelservice`
  CR and the same `llm-d.ai/model` label on the `inferencepool` that the EPP is watching.

Lets examine on what the `msg`s will look like in the `endpoint-picker` pod.

```log
{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"handlers/request.go:74","msg":"LLM request assembled","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","session id":"6fda31b6-43cb-49e4-8914-9b7d553e3a28"}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:105","msg":"Scheduling a request. Metrics: [{score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps Address:10.128.10.55} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.473752256 +0000 UTC m=+123.248280559}} {score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp Address:10.131.9.23} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.475305094 +0000 UTC m=+123.249833388}}]","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0"}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:152","msg":"Before running filter plugins","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","pods":[{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps"},"Address":"10.128.10.55","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.473752256Z"},{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp"},"Address":"10.131.9.23","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.475305094Z"}]}
{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:154","msg":"Running filter plugin","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","plugin":"DefaultPlugin"}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:162","msg":"Filter plugin result","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","plugin":"DefaultPlugin","pods":[{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps"},"Address":"10.128.10.55","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.473752256Z"},{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp"},"Address":"10.131.9.23","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.475305094Z"}]}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:164","msg":"After running filter plugins","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","pods":[{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps"},"Address":"10.128.10.55","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.473752256Z"},{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp"},"Address":"10.131.9.23","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.475305094Z"}]}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:170","msg":"Before running score plugins","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","pods":[{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps"},"Address":"10.128.10.55","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.473752256Z"},{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp"},"Address":"10.131.9.23","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.475305094Z"}]}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:178","msg":"After running score plugins","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","pods":[{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps"},"Address":"10.128.10.55","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.473752256Z"},{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp"},"Address":"10.131.9.23","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.475305094Z"}]}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","logger":"max-score-picker","caller":"pickers/max-score.go:24","msg":"Selecting the pod with the max score from 2 candidates: [{score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps Address:10.128.10.55} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.473752256 +0000 UTC m=+123.248280559}} {score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp Address:10.131.9.23} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.475305094 +0000 UTC m=+123.249833388}}]","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false...

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","logger":"max-score-picker","caller":"pickers/max-score.go:45","msg":"Multiple pods have the same max score (0.000000): [{score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps Address:10.128.10.55} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.473752256 +0000 UTC m=+123.248280559}} {score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp Address:10.131.9.23} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.475305094 +0000 UTC m=+123.249833388}}]","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, Prom...

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"pickers/random.go:39","msg":"Selecting a random pod from 2 candidates: [{score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-decode-6b8f48ddc4-hv2ps Address:10.128.10.55} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.473752256 +0000 UTC m=+123.248280559}} {score:0 Pod:{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp Address:10.131.9.23} Metrics:{ActiveModels:map[] WaitingModels:map[] MaxActiveModels:0 RunningQueueSize:0 WaitingQueueSize:0 KVCacheUsagePercent:5.310110450296168e-05 KvCacheMaxTokenCapacity:0 UpdateTime:2025-04-30 21:04:31.475305094 +0000 UTC m=+123.249833388}}]","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0"}

{"level":"Level(-4)","ts":"2025-04-30T21:04:31Z","caller":"scheduling/scheduler.go:124","msg":"After running picker plugins","request":"Model: Llama-3.2-3B-Instruct, TargetModels: map[], ResolvedTargetModel: Llama-3.2-3B-Instruct, Critical: false, PromptLength: 0","result":{"TargetPod":{"NamespacedName":{"Namespace":"e2e-helm","Name":"llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp"},"Address":"10.131.9.23","ActiveModels":{},"WaitingModels":{},"MaxActiveModels":0,"RunningQueueSize":0,"WaitingQueueSize":0,"KVCacheUsagePercent":0.00005310110450296168,"KvCacheMaxTokenCapacity":0,"UpdateTime":"2025-04-30T21:04:31.475305094Z"}}}

{"level":"Level(-2)","ts":"2025-04-30T21:04:31Z","caller":"handlers/request.go:102","msg":"Request handled","model":"Llama-3.2-3B-Instruct","targetModel":"Llama-3.2-3B-Instruct","endpoint":"{NamespacedName:e2e-helm/llama-32-3b-instruct-model-service-prefill-5964cf8484-9hlrp Address:10.131.9.23}"}

{"level":"Level(-3)","ts":"2025-04-30T21:04:32Z","caller":"handlers/response.go:55","msg":"Response generated","usage":{"prompt_tokens":6,"completion_tokens":50,"total_tokens":56}}
```
