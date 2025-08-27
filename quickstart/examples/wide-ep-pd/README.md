## Installation

1. Install your local dependencies (from `/llm-d-infra/quickstart`)

   ```bash
   ./install-deps.sh
   ```

1. Use the quickstart to deploy Gateway CRDS + Gateway provider + Infra chart (from `/llm-d-infra/quickstart`). This example only works out of the box with `Istio` as a provider, but with changes its possible to run this with `kgateway`.

   ```bash
   export HF_TOKEN=${HFTOKEN}
   ./llmd-infra-installer.sh --namespace llm-d-wide-ep-pd -r infra-wide-ep-pd -f examples/wide-ep-pd/infra-wide-ep-pd/values.yaml --disable-metrics-collection
   ```

   **_NOTE:_** The release name `infra-wide-ep-pd` is important here, because it matches up with pre-built values files used in this example.

1. Use the helmfile to apply the modelservice chart on top of it

   ```bash
   ./patch-istio-deployment.sh
   cd examples/wide-ep-pd
   helmfile --selector managedBy=helmfile apply -f helmfile.yaml --skip-diff-on-install
   ```
