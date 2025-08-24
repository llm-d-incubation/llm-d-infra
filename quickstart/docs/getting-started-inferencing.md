# Requesting the quickstart Stack

## Pre-requistes

This document is meant to pick up after you have deployed a quickstart and walk you through sending requests and interacting with the stack you just deployed.

## Exposing your gateway

First we need to choose what strategy were going to use to expose / interact with our gateway. It should be noted that this will be affected by the values you used when installing the `llm-d-infra` chart for your given quickstart. There are three options:

1. Port-forward the gateway service to localhost
    - Pros: works on any k8s cluster type
    - Cons: requires k8s user access
2. Using the gateway's external IP address
    - Pros: publicly accessible endpoint
    - Cons: environment dependent - depends on your `Service.type=LoadBalancer` and cloud-provider integration to your k8s cluster
3. Using an ingress attached to the gateway service
    - Pros:
        - Stable hostname
        - Optional TLS and Traffic policies
    - Cons:
        - Depends on an ingress controller
        - Depends on configuring DNS

**_NOTE:_** If you’re unsure which to use—start with port-forward as its the most reliable and easiest. For anything shareable, use Ingress/Route. Use LoadBalancer if your provider supports it and you just need raw L4 access.

**_NOTE:_** It should also be noted that you can use other platform specific networking options such as Openshift Routes. However this is obviously platform dependent and can also cause externalities. When benchmarking the `pd-dissagregation` example with OCP routes we noticed that Openshift Networking was enforcing timeouts on gateway requests, which, under heavy load affected our results. If you wish to use a platform dependent option with a benchmarking setup ensure to check your platform docs.

Each of these paths should export the `${ENDPOINT}` environment variable which we can send requests to.

### Port-forward to Localhost 

Given a `$NAMESPACE` you can grab your gateway service name with the following.

```bash
GATEWAY_SVC=$(kubectl get svc -n "${NAMESPACE}" -o yaml | yq '.items[] | select(.metadata.name | test(".*-inference-gateway(-.*)?$")).metadata.name' | head -n1)
```

**_NOTE:_** This command assumes you have one gateway in your given `${NAMESPACE}`, even if you have multiple it will only grab the name of the first gateway service in alphabetical order. If you are running multiple quickstarts in a singular namespace, you will have to explicitly set your `$GATEWAY_SVC` by listing services, finding the right one and exporting it, ex:

```bash
k get services
NAME                                                 TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                        AGE
gaie-inference-scheduling-epp                        ClusterIP      10.16.3.250   <none>        9002/TCP,9090/TCP              18s
gaie-inference-scheduling-ip-18c12339                ClusterIP      None          <none>        54321/TCP                      12s
gaie-sim-epp                                         ClusterIP      10.16.1.220   <none>        9002/TCP,9090/TCP              80m
infra-inference-scheduling-inference-gateway-istio   LoadBalancer   10.16.3.226   10.16.4.3     15021:34529/TCP,80:35734/TCP   22s
infra-sim-inference-gateway                          LoadBalancer   10.16.1.62    10.16.4.2     80:38348/TCP                   81m

export GATEWAY_SVC="infra-inference-scheduling-inference-gateway-istio"
```

After we have our gateway service name, we can portforward it:

```bash
export ENDPOINT="http://localhost:8000"
kubectl port-forward -n ${NAMESPACE} service/${GATEWAY_SVC} 8000:80
```

**_NOTE:_** in all of our quickstarts, 8000 is the default gateway service port. You can change this by adjusting the values for the `llm-d-infra` helm chart, and if you do make sure to adjust your port-forward command.

### Using the Gateway External IP with service type `LoadBalancer`

> [!REQUIREMENTS]
> This requires that the release of the `llm-d-infra` chart must have `.gateway.serviceType` set to `LoadBalancer`. Currently this is the [default value](https://github.com/llm-d-incubation/llm-d-infra/blob/main/charts/llm-d-infra/values.yaml#L167), however its worth noting.
> This requires your K8s cluster is deployed on a cloud provider with LB integration (EKS/GKE/AKS/AWS/…).

If you are using the GKE gateway or have are using the default service type of `LoadBalancer` for you gateway and you are on a cloud platform with loadbalancing, you can use the `External IP` of your gateway service (you should see the same thing under your gateway with `kubectl get gateway`.)

```bash
export ENDPOINT=$(kubectl get gateway --no-headers -n ${NAMESPACE} -o jsonpath='{.items[].status.addresses[0].value}')
```

**_NOTE:_** This command assumes you have one gateway in your given `${NAMESPACE}`, if you have multiple, it will just grab one. Therefor, in the case you do have multiple gateways, you should find the correct gateway and target that specifically:

```bash
kubectl get gateway -n ${NAMESPACE}
NAME                                           CLASS      ADDRESS                                                                   PROGRAMMED   AGE
infra-inference-scheduling-inference-gateway   kgateway   af805bef3ec444a558da28061b487dd5-2012676366.us-east-1.elb.amazonaws.com   True         11m
infra-sim-inference-gateway                    kgateway   a67ad245358e34bba9cb274bc220169e-1351042165.us-east-1.elb.amazonaws.com   True         45s

GATEWAY_NAME=infra-inference-scheduling-inference-gateway
export ENDPOINT=$(kubectl get gateway ${GATEWAY_NAME} --no-headers -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')
```

### Using an ingress

> [!REQUIREMENT]
> This requires that the release of the `llm-d-infra` chart must have `.ingress.enabled` set to `true`, and the `.ingress.host` to be set to a valid address you own the DNS records for.


## Sending the Requests

In this example since we are port-forwarding, we know that our endpoint will be localhost:



1. Try curling the `/v1/models` endpoint:

```bash
curl -s ${ENDPOINT}/v1/models \
  -H "Content-Type: application/json" | jq
{
  "data": [
    {
      "created": 1752727169,
      "id": "random",
      "object": "model",
      "owned_by": "vllm",
      "parent": null,
      "root": "random"
    },
    {
      "created": 1752727169,
      "id": "",
      "object": "model",
      "owned_by": "vllm",
      "parent": "random",
      "root": ""
    }
  ],
  "object": "list"
}
```

1. Try curling the `v1/completions` endpoint:

```bash
curl -X POST ${ENDPOINT}/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{
        "model": "random",
        "prompt": "How are you today?"
      }' | jq
{
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "Today is a nice sunny day.",
        "role": "assistant"
      }
    }
  ],
  "created": 1752727735,
  "id": "chatcmpl-af42e9e3-dab0-420f-872b-d23353d982da",
  "model": "random"
}
```
