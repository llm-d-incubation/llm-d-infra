# Leader Worker Set installation

If you want to use a "wide-expert parallel" pattern, rolling out llm-d deployments accross multiple nodes, you will need to install LeaderWorkerSet. You can use this leveraging the `helmfile`:

```bash
helmfile apply
```

## Provider support

It should be noted that LWS is not currently supported in K8s environments with stricter security concerns, such as OCP.