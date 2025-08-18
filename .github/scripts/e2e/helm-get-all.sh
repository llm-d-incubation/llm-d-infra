#!/usr/bin/env sh
set -eu

if [ $# -ne 2 ]; then
  echo "Usage: $0 path/to/logfile path/to/helmfile.yaml" >&2
  echo "Optional: \`\${BACKUP_NAMESPACE}\` - If namespace not set in the helmfile, this will be selected as the namespace."
  exit 1
fi

LOG_FILE="$1"
HELMFILE="$2"

if [ ! -f "${LOG_FILE}" ]; then
  echo "Cannot find the required LOG_FILE at path: ${LOG_FILE}"
  exit 1
fi

if [ ! -f "${HELMFILE}" ]; then
  echo "Cannot find the required HELMFILE at path: ${HELMFILE}"
  exit 1
fi

if [ -n ${BACKUP_NAMESPACE} ]; then
    echo "Env value \`BACKUP_NAMESPACE\` set to: ${BACKUP_NAMESPACE}."
fi

# mikefarah yq v4 syntax; note: the field is usually .namespace (singular)
yq -r '.releases[] | [.namespace, .name] | @tsv' ${HELMFILE} \
| while IFS="$(printf '\t')" read -r ns rel; do
  # Default namespace if omitted in the helmfile
  if [ -z "${ns}" ]; then
    if [ -n "${BACKUP_NAMESPACE}" ]; then
        export ns="${BACKUP_NAMESPACE}"
    else
        export ns="default"
    fi
  fi

  echo "Logging $ns/$rel..."
  helm get all -n "$ns" "$rel" >> "${LOG_FILE}" || true
done

echo "Wrote logs to ${LOG_FILE}"
