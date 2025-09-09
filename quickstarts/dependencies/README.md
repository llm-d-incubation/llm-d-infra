# Quickstart Dependencies

This folder houses the client‑side tooling needed to use the LLM‑D quickstarts (e.g., kubectl, helm, helmfile, gh, yq, etc.). By keeping the install scripts and this doc together, we can version and update them in one place.

To install the dependencies, use the provided [install-deps.sh](./install-deps.sh).

## Supported Development Platforms

Currently LLM-D community only supports OSX and Linux development.

## Required Tools

Following prerequisite are required for the installer to work.

| Binary      | Minimum Required Version | Download / Installation Instructions                                                            |
| ----------- | ------------------------ | ----------------------------------------------------------------------------------------------- |
| `yq`        | v4+                      | [yq (mikefarah) – installation](https://github.com/mikefarah/yq?tab=readme-ov-file#install)     |
| `git`       | v2.30.0+                 | [git – installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)       |
| `helm`      | v3.12.0+                 | [Helm – quick-start install](https://helm.sh/docs/intro/install/)                               |
| `helmfile`  | v1.1.0+                  | [Helmfile - installation](https://github.com/helmfile/helmfile?tab=readme-ov-file#installation) |
| `kubectl`   | v1.28.0+                 | [kubectl – install & setup](https://kubernetes.io/docs/tasks/tools/install-kubectl/)            |
| ----------- | ------------------------ | ----------------------------------------------------------------------------------------------- |

### Optional Tools

| Binary             | Recommended Version      | Download / Installation Instructions                                                             |
| ------------------ | ------------------------ | ------------------------------------------------------------------------------------------------ |
| `stern`            | 1.30+                    | [stern - installation](https://github.com/stern/stern?tab=readme-ov-file#installation)           |
| `helm diff` plugin | v3.10.0+                 | [helm diff installation docs](https://github.com/databus23/helm-diff?tab=readme-ov-file#install) |
| ------------------ | ------------------------ | ------------------------------------------------------------------------------------------------ |

## HuggingFace Token

Most of these quickstarts download their model from Huggingface directly in the `llm-d` image. There are exceptions to this like the [`sim` example](../examples/sim/) that uses no model, or the [`wide-ep-lws` example](../examples/wide-ep-lws/) which uses a model loaded from storage directly on the nodes for faster development cycle iterations.

For the rest however, you will need to the secret containing your HuggingFace Token. For more information on getting a token, see [the huggingface docs](https://huggingface.co/docs/hub/en/security-tokens).

Once you have a token value you create the k8s secret to hold it:

```bash
export HF_TOKEN=...
export HF_TOKEN_NAME=${HF_TOKEN_NAME:-llm-d-hf-token}
export NAMESPACE=...
kubectl create secret generic ${HF_TOKEN_NAME} \
    --from-literal="HF_TOKEN=${HF_TOKEN}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
```

## Pulling LLM-D Images from GHCR

All of our container images on the `llm-d` organization on github are public. Because of this you should not need any authentication to pull any of them.
