# Contributing to llm-d chart

## Governance Structure

`llm-d-deployer` adopts the following hierarchical technical governance structure:

- A community of **contributors** who file issues and submit pull requests
- A body of **core maintainers** who own `llm-d-deployer` overall and drive its development
- A **lead core maintainer** who is the catch-all decision maker when consensus cannot be reached by core maintainers

All contributions are expected to follow `llm-d-deployer` design principles and best helm pracises, as enforced by core maintainers. While high-quality pull requests are appreciated and encouraged, all maintainers reserve the right to prioritize their own work over code reviews at-will, hence contributors should not expect their work to be reviewed promptly.

Contributors can maximize the chances of their work being accepted by maintainers by meeting a high quality bar before sending a PR to maintainers.

### Core maintainers

The core maintainers drive the development of `llm-d-deployer` at large and set the roadmap for the `llm-d` project. As such, they have the following responsibilities:

- Proposing, implementing and reviewing profound changes to user-facing APIs, IR specifications and/or pass infrastructures
- Enforcing code quality standards and adherence to core design principles

The core maintainers should publicly articulate their decision-making, and share the reasoning behind their decisions, vetoes, and dispute resolution.

List of core maintainers can be found in the [OWNERS](OWNERS) file.

### Lead core maintainer

When core maintainers cannot come to a consensus, a publicly declared lead maintainer is expected to settle the debate and make executive decisions.

The Lead Core Maintainer should publicly articulate their decision-making, and give a clear reasoning for their decisions.

The Lead Core Maintainer is also responsible for confirming or removing core maintainers.

#### Lead maintainer (as of 13/05/2025)

- [Tom Coufal](https://github.com/tumido)

### Decision Making

#### Uncontroversial Changes

We are committed to accepting functional bug fixes that meet our quality standards – and include minimized unit tests to avoid future regressions. Performance improvements generally fall under the same category, with the caveat that they may be rejected if the trade-off between usefulness and complexity is deemed unfavorable by core maintainers. Design changes that neither fix known functional nor performance issues are automatically considered controversial.

#### Controversial Changes

More controversial design changes (e.g., breaking changes to the chart) are evaluated on a case-by-case basis under the subjective judgment of core maintainers.

## Submitting a Pull Request

We welcome contributions to the llm-d chart! If you have a bug fix, feature request, or improvement, please submit a pull request (PR) to the repository.

Before submitting a pull request, please ensure that you have following dependencies installed and set up:

- [Helm](https://helm.sh/)
- [Helm docs](https://github.com/norwoodj/helm-docs)
- [pre-commit](https://pre-commit.com/)

Then run:

```bash
pre-commit install

helm repo add bitnami https://charts.bitnami.com/bitnami
helm dependency update charts/llm-d-infra
helm dependency build charts/llm-d-infra

pre-commit run -a
```

For every Pull Request submitted, ensure the following steps have been done:

1. [Sign your commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)
2. [Sign-off your commits](https://git-scm.com/docs/git-commit#Documentation/git-commit.txt-code--signoffcode)
3. Run `helm template` on the changes you're making to ensure they are correctly rendered into Kubernetes manifests.
4. Lint tests has been run for the Chart using the [Chart Testing](https://github.com/helm/chart-testing) tool and the `ct lint` command.
5. Ensure variables are documented in `values.yaml`. See section [Documenting Variables](#documenting-variables) below.
6. Update the version number in the [`charts/llm-d-infra/Chart.yaml`](charts/llm-d-infra/Chart.yaml) file using
   [semantic versioning](https://semver.org/). Follow the `X.Y.Z` format so the nature of the changes is reflected in the
   chart.
   - `X` (major) is incremented for breaking changes,
   - `Y` (minor) is incremented when new features are added without breaking existing functionality,
   - `Z` (patch) is incremented for bug fixes, minor improvements, or non-breaking changes.
7. Make sure that [pre-commit](https://pre-commit.com/) hook has been run to generate/update the `README.md` documentation. To preview the content, use `helm-docs --dry-run`.

### FAQ and Troubleshooting

#### Documenting Variables

When adding new variables to the `values.yaml` file, please ensure that you document them in the file. The documentation should include:

- A brief description of the variable
- A guideline for schema generator for nontrivial types

We use a combination of [`helm-docs`](https://github.com/norwoodj/helm-docs) and [`helm-schema`](https://github.com/dadav/helm-schema/) to generate the documentation for the chart. The documentation is generated in the `README.md` file and schema in `values.schema.json`.

A properly documented value should look like this:

```yaml
# -- Enable something
enabled: true
```

The default behavior is to use the actual value of the variable as the default value in documentation. If you want to override it, you can use the `@default -- <value>` directive. This is useful to hide complex values or to provide a more user-friendly default value.

```yaml
# -- Tolerations configuration
# @default -- See below
tolerations:
# -- Default NVIDIA GPU toleration
- key: nvidia.com/gpu
   operator: Exists
   effect: NoSchedule
```

Generates:

```md
| tolerations | Tolerations configuration | list | See below |
| tolerations[0] | Default NVIDIA GPU toleration | object | `{"effect":"NoSchedule","key":"nvidia.com/gpu","operator":"Exists"}` |
```

For nontrivial types, you we need to guide the schema generator using the `@schema` directive. This is useful for complex types like `object`, `map`, with unknown keys, or for incomplete types like empty `array` or `map`. See [available annotations in `helm-schema`](https://github.com/dadav/helm-schema/#available-annotations) for more details.

```yaml
# @schema
# items:
#   type: [string, object]
# @schema
# -- Array of extra objects to deploy with the release
extraDeploy: []
```

> [!TIP]
> For values that match a specific JSON schema that already exist remotely, you can use the `@schema` directive with `$ref` value pointing to the URL of the schema reference.
>
> ```yaml
> # @schema
> # $ref: https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master/_definitions.json#/definitions/io.k8s.apimachinery.pkg.apis.meta.v1.LabelSelector
> # @schema
> matchLabels: {}
> ```

#### I see weird errors when running `helm template`, `helm install`, `pre-commit run`

The error message looks like this:

```bash
$ pre-commit run -a
...
helmlint.................................................................Failed
- hook id: helmlint
- exit code: 1

==> Linting /Users/rcook/git/llm-d-deployer/charts/llm-d-infra
[ERROR] templates/: template: llm-d/templates/modelservice/presets/basic-gpu-with-nixl-preset.yaml:6:8: executing "llm-d/templates/modelservice/presets/basic-gpu-with-nixl-preset.yaml" at <include "common.labels.standard" .>: error calling include: template: no template "common.labels.standard" associated with template "gotpl"
[WARNING] /Users/rcook/git/llm-d-deployer/charts/llm-d-infra: chart directory is missing these dependencies: common,redis

Error: 1 chart(s) linted, 1 chart(s) failed

markdownlint-cli2....................................(no files to check)Skipped
...
```

- Ensure that you have the up-to-date version of Helm installed.
- Check if you have the required dependencies installed and updated. You can do this by running `helm dependency update charts/llm-d-infra`.
- If you are using a custom values file, ensure that it is correctly formatted and does not contain any syntax errors.

#### PR check `Lint Charts / Lint Metadata (pull_request)` is failing

Please see the job logs for more details. You've most likely forgot to update the `Chart.yaml` file with the new version number. Please see step 5 above.

#### PR check `Pre-commit / Pre-commit (pull_request)` is failing

Please see the job logs for more details. You've most likely forgot to run `pre-commit run -a` before submitting the PR. Please see setup steps above. To prevent this from happening in the future, please ensure that you have run `pre-commit install` to install the pre-commit hooks.

### Tips and Tricks

#### Quick rebase when other PRs are merged

Incoming PRs will most definitely cause merge conflicts with your PR since they bump the version number in the `Chart.yaml` file. To quickly rebase your PR, run the following command:

```bash
# Update your local main branch with the latest changes from upstream.
git checkout main
git fetch upstream
git rebase upstream/main
git push main

# Now update your local branch with the latest changes from main.
git checkout <your-branch>
git rebase main

# Now the rebase conflict occurs.

# Now edit the `Chart.yaml` file and bump the version number to the next version. See step 5 above.
git add charts/llm-d-infra/Chart.yaml
pre-commit run helm-docs
git add .
# Now the merge conflict is resolved, you can continue with the rebase.
git rebase --continue

# Now the rebase is done, you can push the changes to your branch.
git push -f origin <your-branch>
```

#### See your changes in the chart

```bash
helm template charts/llm-d-infra
```

#### Quickly filter out the `helm template` output

For example, to see the `eppDeployment` from all rendered `ConfigMap`s:

```bash
helm template charts/llm-d-infra | yq 'select(.kind == "ConfigMap") | .data.eppDeployment'
```

#### Double templating in modelservice presets/base config

The `modelservice` base configuration `ConfigMaps` located in [`chart/llm-d/templates/modelservice/presets`](chart/llm-d/templates/modelservice/presets) are go templates.

Since we include them into a Helm chart - as helm templates - they are rendered twice. The first time, the template is rendered into a Kubernetes manifest by Helm and the second time, the template is rendered/interpreted by `modelservice` controller when instantiating the `ModelService` CR.

Model service controller provides following template variables localized to the `ModelService` CR context:

| Variable                | Meaning                                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------------------------ |
| `.ModelServiceName`      | The name of the `ModelService` CR                                                                      |
| `.ModelServiceNamespace` | The namespace where the `ModelService` CR is deployed to                                               |
| `.ModelName`             | The name of the model                                                                                  |
| `.HFModelName`           | Hugging Face repository name in form `<org>/<repo>` available for models loaded from Hugging Face only |
| `.SanitizedModelName`    | The model name sanitized to be used for DNS addressable names                                          |
| `.ModelPath`             | Local path to the model location                                                                       |
| `.EPPServiceName`        | The name of the endpoint picker `Service` created for the `ModelService` CR                            |
| `.EPPDeploymentName`     | The name of the endpoint picker `Service` created for the `ModelService` CR                            |
| `.PrefillDeploymentName` | The name of the prefill `Deployment` created for the `ModelService` CR                                 |
| `.DecodeDeploymentName`  | The name of the decode `Deployment` created for the `ModelService` CR                                  |
| `.PrefillServiceName`    | The name of the prefill `Service` created for the `ModelService` CR                                    |
| `.DecodeServiceName`     | The name of the decode `Service` created for the `ModelService` CR                                     |
| `.InferencePoolName`     | The name of the InferencePool`CR created for the`ModelService` CR                                      |
| `.InferenceModelName`    | The name of the `InferenceModel` CR created for thee `ModelService` CR                                 |

You can refer to:

- The [modelservice samples](https://github.com/llm-d/llm-d-model-service/tree/main/samples) for additional context on the model service controller usage.
- The [go template documentation](https://pkg.go.dev/text/template) for more details on the available template functions and syntax.

Since in our chart the templates are rendered twice, we need to escape the go templates meant to be rendered by model service controller (not Helm) as strings via `{{` and `}}` delimiters. This is done by wrapping the template within in backticks `` ` ``.

That means, if you want the model service to render a template like this:

```yaml
{{ default (print "/models/" .ModelPath) .HFModelName }}
```

In our chart, you need to write it like this:

```yaml
{{ `{{ default (print "/models/" .ModelPath) .HFModelName }}` }}
```
