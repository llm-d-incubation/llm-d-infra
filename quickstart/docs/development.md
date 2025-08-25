# Development documentation

This doc is meant to track helpful workarounds for development.

## `llm-d-infra` charts

Here are a few suggestions for development experience `llm-d-infra` helm charts.

### Schema Validation Workarounds

In an effort to some guadrails around values, we utilize a helm values schema in the infra charts. However this can cause headaches when testing feature changes. The `pre-commit` automation we have setup should automatically pick up changes to the values and propagate them into the schema, however sometimes if you don't properly annotate the `values.yaml` file with annotations to explain the schema of objects, it can throw errors for schema validations. If you encounter these you can use the `--skip-schema-validation` command with `helm upgrade` until you can go back and fix those comments - heres an example:

```bash
# ran from charts/llm-d-infra
helm upgrade -i my-infra-release ./ --skip-schema-validation
```

For more information on helm schema check out [their repo](https://github.com/dadav/helm-schema/).

### Using the `helm template` command

When testing features in the charts you might want to inspect the manifests, this is where the `--template` command is very helpful:

```bash
# ran from charts/llm-d-infra
helm template -i my-infra-release ./ --debug
```

**_NOTE:_** the `--debug` flag as shown above is very helpful with templating, because if the templates have improper spacing rules it will show you this in line.

## Quickstart examples

### Using local charts
