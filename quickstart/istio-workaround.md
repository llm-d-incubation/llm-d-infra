# Temporary Istio Workaround

## Istio TLS Connection

If you are using Istio as your gateway provider, apply this temporary workaround.
Currently, the EPP service uses the default self-signed certificates for its internal communication.
Istio's Envoy proxy will terminate the TLS connection because it cannot validate these self-signed certificates.
To resolve this, you can apply an Istio `DestinationRule`. This rule instructs Envoy to initiate a `SIMPLE` TLS
connection to the EPP service but to skip the certificate verification, allowing the connection to succeed.

-----

### Applying the Fix

The following will set the required variables from your deployment and apply the `DestinationRule`.

1. Set the namespace:

   ```bash
   export EPP_NAMESPACE="llm-d"
   ```

2. Find and set the EPP service name:

   ```bash
   export EPP_NAME=$(kubectl get svc -n "${EPP_NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -- "-epp" | head -n1)
   ```

3. Apply the `DestinationRule`:

   ```bash
   cat <<EOF | kubectl apply -n "${EPP_NAMESPACE}" -f -
   apiVersion: networking.istio.io/v1
   kind: DestinationRule
   metadata:
     name: ${EPP_NAME}-insecure-tls
   spec:
     host: ${EPP_NAME}
     trafficPolicy:
       tls:
         mode: SIMPLE
         insecureSkipVerify: true
   EOF
   ```
