#!/usr/bin/env sh
set -eu

if [ ! $(command -v helm) ]; then
  echo "\`helm\` is required for this script, please install helm"
  exit 1
fi

if [ $# -ne 3 ]; then
  echo "Usage: $0 path/to/logfile RELEASE_NAME NAMESPACE" >&2
  exit 1
fi

LOG_FILE="$1"
RELEASE_NAME="$2"
NAMESPACE="$3"

if [ ! -f "${LOG_FILE}" ]; then
  echo "Cannot find the required LOG_FILE at path: ${LOG_FILE}"
  exit 1
fi

helm get all ${RELEASE_NAME} -n ${NAMESPACE} 2&>1 > /dev/null

if [ "${$?}" == "0" ]; then
  echo "==============================================================" >> "${LOG_FILE}"
  echo "             Logging ${NAMESPACE}/${RELEASE_NAME}..." >> "${LOG_FILE}"
  echo "==============================================================" >> "${LOG_FILE}"
  helm get all -n "${RELEASE_NAME}" "${RELEASE_NAME}" >> "${LOG_FILE}" || true
  echo "==============================================================" >> "${LOG_FILE}"
  echo "                                                              " >> "${LOG_FILE}"
  echo "                                                              " >> "${LOG_FILE}"
else
  echo "Could not find release ${RELEASE_NAME} in namespace ${NAMESPACE}!" >> "${LOG_FILE}"
fi
