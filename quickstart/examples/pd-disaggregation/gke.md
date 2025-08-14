# PD Disaggregation on GKE

## Installation

1. Install your local dependencies (from `/llm-d-infra/quickstart`)

    ```bash
    ./install-deps.sh
    ```

1. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart (from `/llm-d-infra/quickstart`).

    ```bash
    # Set common environment variables
    export NAMESPACE=llm-d-pd
    export GATEWAY=gke-l7-regional-external-managed
    ```

    ```bash
    # From the repo root
    cd quickstart
    export HF_TOKEN=$(YOUR_TOKEN)
    ./llmd-infra-installer.sh --namespace ${NAMESPACE} -r infra-pd --gateway ${GATEWAY} --disable-metrics-collection
    ```

1. Use the helmfile to apply the modelservice and GIE charts on top of it.

   - `--set provider.name=gke`: Sets the gaie gateway provider to `gke` so the chart will install GKE gateway related resources (`gcpbackendpolicy` and `healthcheckpolicy`).
   - `--set 'decode.containers[0].resources.limits.rdma/ib=null'`: The example runs on GCP H200 instances which don't the `rdma/ib` resources out of the box.

    ```bash
    cd examples/pd-disaggregation
    helmfile --namespace ${NAMESPACE} --selector managedBy=helmfile \
    --set provider.name=gke \
    --set 'decode.containers[0].resources.limits.rdma/ib=null' \
    --set 'decode.containers[0].resources.requests.rdma/ib=null' \
    --set 'prefill.containers[0].resources.limits.rdma/ib=null' \
    --set 'prefill.containers[0].resources.requests.rdma/ib=null' \
    apply -f gke.helmfile.yaml --skip-diff-on-install
    ```

## Verifying the installation

1. First lets check that all three charts were deployed successfully to our chosen namespace:

    ```bash
    $ helm list -n ${NAMESPACE}
    NAME        NAMESPACE    REVISION    UPDATED                                 STATUS      CHART                       APP VERSION
    gaie-pd     llm-d-pd     1           2025-07-25 11:27:47.419598 -0700 PDT    deployed    inferencepool-v0.5.1        v0.5.1
    infra-pd    llm-d-pd     1           2025-07-25 11:27:18.453254 -0700 PDT    deployed    llm-d-infra-v1.1.1          v0.2.0
    ms-pd       llm-d-pd     1           2025-07-25 11:27:53.138175 -0700 PDT    deployed    llm-d-modelservice-0.2.0    v0.2.0
    ```

1. Next lets check our pod health of our 4 prefill replicas and 1 decode replica:

    ```bash
    $ kubectl get pods -n ${NAMESPACE}
    NAME                                                READY   STATUS    RESTARTS   AGE
    gaie-pd-epp-69888bdd8d-6pnbk                        1/1     Running   0          54s
    infra-pd-inference-gateway-istio-776797b79f-6clvr   1/1     Running   0          2m9s
    ms-pd-llm-d-modelservice-decode-65f7f65cf6-2fh62    2/2     Running   0          50s
    ms-pd-llm-d-modelservice-prefill-549598dd6c-6f757   1/1     Running   0          49s
    ms-pd-llm-d-modelservice-prefill-549598dd6c-6n4bc   1/1     Running   0          49s
    ms-pd-llm-d-modelservice-prefill-549598dd6c-ft89l   1/1     Running   0          49s
    ms-pd-llm-d-modelservice-prefill-549598dd6c-pbjzx   1/1     Running   0          49s
    ```

1. Get the gateway endpoint:

    ```bash
    GATEWAY_NAME=infra-pd-inference-gateway
    IP=$(kubectl get gateway/${GATEWAY_NAME} -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')

    PORT=80
    ```

1. Try curling the `/v1/models` endpoint:

    ```bash
    curl -s http://${IP}:${PORT}/v1/models \
      -H "Content-Type: application/json" | jq
    {
      "data": [
        {
          "created": 1753468493,
          "id": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic",
          "max_model_len": 32000,
          "object": "model",
          "owned_by": "vllm",
          "parent": null,
          "permission": [
            {
              "allow_create_engine": false,
              "allow_fine_tuning": false,
              "allow_logprobs": true,
              "allow_sampling": true,
              "allow_search_indices": false,
              "allow_view": true,
              "created": 1753468493,
              "group": null,
              "id": "modelperm-df4f0c7555e648fe82a3a952d0634e20",
              "is_blocking": false,
              "object": "model_permission",
              "organization": "*"
            }
          ],
          "root": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic"
        }
      ],
      "object": "list"
    }
    ```

1. Try curling the `v1/completions` endpoint:

    ```bash
    curl -s http://${IP}:${PORT}/v1/completions \
      -H "Content-Type: application/json" \
      -d '{
        "model": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic",
        "prompt": "How are you today?",
        "max_tokens": 50
      }' | jq
    {
      "choices": [
        {
          "finish_reason": "length",
          "index": 0,
          "logprobs": null,
          "prompt_logprobs": null,
          "stop_reason": null,
          "text": " I hope you are having a great day so far. I just wanted to remind you that you are not alone. No matter what you are going through, you have people who care about you and want to help.\nIf you are struggling with difficult emotions"
        }
      ],
      "created": 1753468566,
      "id": "cmpl-e18c8248-bcd7-4c26-a7fc-a7e214dc3ff1",
      "kv_transfer_params": null,
      "model": "RedHatAI/Llama-3.3-70B-Instruct-FP8-dynamic",
      "object": "text_completion",
      "service_tier": null,
      "system_fingerprint": null,
      "usage": {
        "completion_tokens": 50,
        "prompt_tokens": 6,
        "prompt_tokens_details": null,
        "total_tokens": 56
      }
    }
    ```

## Cleanup

To remove the deployment:

```bash
# Remove the model services
helmfile --selector managedBy=helmfile destroy --namespace ${NAMESPACE}

# Remove the infrastructure
helm uninstall infra-pd -n ${NAMESPACE}
```

## Customization

- **Change model**: Edit `ms-pd/values.yaml` and update the `modelArtifacts.uri` and `routing.modelName`
- **Adjust resources**: Modify the GPU/CPU/memory requests in the container specifications
- **Scale workers**: Change the `replicas` count for decode/prefill deployments
