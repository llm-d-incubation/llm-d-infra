create_pvc_and_download_model_if_needed() {
  YQ_TYPE=$(yq --version 2>/dev/null | grep -q 'version' && echo 'go' || echo 'py')
  MODEL_ARTIFACT_URI=$(cat ${VALUES_PATH} | yq .sampleApplication.model.modelArtifactURI)
  PROTOCOL="${MODEL_ARTIFACT_URI%%://*}"

  verify_env() {
    if [[ -z "${MODEL_ARTIFACT_URI}" ]]; then
        log_error "No Model Artifact URI set. Please set the \`.sampleApplication.model.modelArtifactURI\` in the values file."
        exit 1
    fi
    if [[ -z "${HF_TOKEN_SECRET_NAME}" ]]; then
        log_error "Error, no HF token secret name. Please set the \`.sampleApplication.model.auth.hfToken.name\` in the values file."
        exit 1
    fi
    if [[ -z "${HF_TOKEN_SECRET_KEY}" ]]; then
        log_error "Error, no HF token secret key. Please set the \`.sampleApplication.model.auth.hfToken.key\` in the values file."
        exit 1
    fi
    if [[ -z "${PVC_NAME}" ]]; then
        log_error "Invalid \$MODEL_ARTIFACT_URI, could not parse PVC name out of \`.sampleApplication.model.modelArtifactURI\`."
        exit 1
    fi
    if [[ -z "${MODEL_PATH}" ]]; then
        log_error "Invalid \$MODEL_ARTIFACT_URI, could not parse Model Path out of \`.sampleApplication.model.modelArtifactURI\`."
        exit 1
    fi
  }

  case "$PROTOCOL" in
  pvc)
    # Used in both conditionals, for logging in else
    PVC_AND_MODEL_PATH="${MODEL_ARTIFACT_URI#*://}"
    PVC_NAME="${PVC_AND_MODEL_PATH%%/*}"
    MODEL_PATH="${PVC_AND_MODEL_PATH#*/}"
    if [[ -n "${DOWNLOAD_MODEL}" ]]; then
      log_info "💾 Provisioning model storage…"

    if [[ "${DOWNLOAD_MODEL}" != */* ]]; then
        log_error "Error, --download-model ${DOWNLOAD_MODEL} is not in Hugging Face compliant format <org>/<repo>."
        exit 1
    fi

      HF_TOKEN_SECRET_NAME=$(cat ${VALUES_PATH} | yq .sampleApplication.model.auth.hfToken.name)
      HF_TOKEN_SECRET_KEY=$(cat ${VALUES_PATH} | yq .sampleApplication.model.auth.hfToken.key)

      DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH=$(realpath "${REPO_ROOT}/helpers/k8s/load-model-on-pvc-template.yaml")

      verify_env

      # If using Minikube, provision hostPath PV/PVC instead of default storage
      if [[ "${USE_MINIKUBE}" == "true" ]]; then
        log_info "⚙️ Minikube mode: setting up hostPath storage"
        setup_minikube_storage
      else
        # verify storage class exists
        log_info "🔍 Checking storage class \"${STORAGE_CLASS}\"..."
        if ! $KCMD get storageclass "${STORAGE_CLASS}" &>/dev/null; then
          log_error "Storage class \`${STORAGE_CLASS}\` not found. Please create it or pass --storage-class with a valid class."
          exit 1
        fi
        # apply the storage manifest
        eval "echo \"$(cat ${REPO_ROOT}/helpers/k8s/model-storage-rwx-pvc-template.yaml)\"" \
          | $KCMD apply -n "${NAMESPACE}" -f -
        log_success "PVC \`${PVC_NAME}\` created with storageClassName ${STORAGE_CLASS} and size ${STORAGE_SIZE}"
      fi

      log_info "🚀 Launching model download job..."
      if [[ "${YQ_TYPE}" == "go" ]]; then
        yq eval "
        (.spec.template.spec.containers[0].env[] | select(.name == \"MODEL_PATH\")).value = \"${MODEL_PATH}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_MODEL_ID\")).value = \"${DOWNLOAD_MODEL}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_TOKEN\")).valueFrom.secretKeyRef.name = \"${HF_TOKEN_SECRET_NAME}\" |
        (.spec.template.spec.containers[0].env[] | select(.name == \"HF_TOKEN\")).valueFrom.secretKeyRef.key = \"${HF_TOKEN_SECRET_KEY}\" |
        (.spec.template.spec.volumes[] | select(.name == \"model-cache\")).persistentVolumeClaim.claimName = \"${PVC_NAME}\"
        " "${DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH}" | $KCMD apply -n ${NAMESPACE} -f -
      elif [[ "${YQ_TYPE}" == "py" ]]; then
        $KCMD apply -f ${DOWNLOAD_MODEL_JOB_TEMPLATE_FILE_PATH} --dry-run=client -o yaml |
        yq -r | \
        jq \
        --arg modelPath "${MODEL_PATH}" \
        --arg hfModelId "${DOWNLOAD_MODEL}" \
        --arg hfTokenSecretName "${HF_TOKEN_SECRET_NAME}" \
        --arg hfTokenSecretKey "${HF_TOKEN_SECRET_KEY}" \
        --arg pvcName "${PVC_NAME}" \
        '
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "MODEL_PATH")).value = $modelPath |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_MODEL_ID")).value = $hfModelId |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_TOKEN")).valueFrom.secretKeyRef.name = $hfTokenSecretName |
        (.spec.template.spec.containers[] | select(.name == "downloader").env[] | select(.name == "HF_TOKEN")).valueFrom.secretKeyRef.key = $hfTokenSecretKey |
        (.spec.template.spec.volumes[] | select(.name == "model-cache")).persistentVolumeClaim.claimName = $pvcName
        ' | yq -y | $KCMD apply -n ${NAMESPACE} -f -
      else
        log_error "unrecognized yq distro -- error"
        exit 1
      fi

      log_info "⏳ Waiting 30 seconds pod to start running model download job ..."
      $KCMD wait --for=condition=Ready pod/$($KCMD get pod --selector=job-name=download-model -o json | jq -r '.items[0].metadata.name') --timeout=60s || {
        log_error "🙀 No pod picked up model download job";
        log_info "Please check your storageclass configuration for the \`download-model\` - if the PVC fails to spin the job will never get a pod"
        $KCMD logs job/download-model -n "${NAMESPACE}";
      }

      log_info "⏳ Waiting up to ${DOWNLOAD_TIMEOUT}s for model download job to complete; this may take a while depending on connection speed and model size..."
      $KCMD wait --for=condition=complete --timeout=${DOWNLOAD_TIMEOUT}s job/download-model -n "${NAMESPACE}" || {
        log_error "🙀 Model download job failed or timed out";
        JOB_POD=$($KCMD get pod --selector=job-name=download-model -o json | jq -r '.items[0].metadata.name')
        $KCMD logs pod/${JOB_POD} -n "${NAMESPACE}";
        exit 1;
      }

      log_success "Model downloaded"
    else
      log_info "⏭️ Model download to PVC skipped: \`--download-model\` arg not set, assuming PVC ${PVC_NAME} exists and contains model at path: \`${MODEL_PATH}\`."
    fi
    ;;
  hf)
    log_info "⏭️ Model download to PVC skipped: BYO model via HF repo_id selected."
    echo "protocol hf chosen - models will be downloaded JIT in inferencing pods."
    ;;
  *)
    log_error "🤮 Unsupported protocol: $PROTOCOL. Check back soon for more supported types of model source 😉."
    exit 1
    ;;
  esac
}

validate_hf_token() {
  if [[ "$ACTION" == "install" ]]; then
    # HF_TOKEN from the env
    [[ -n "${HF_TOKEN:-}" ]] || die "HF_TOKEN not set; Run: export HF_TOKEN=<your_token>"
    log_success "HF_TOKEN validated"
  fi
}

install() {
    log_info "🔐 Creating/updating HF token secret..."
    HF_NAME=$(yq -r .sampleApplication.model.auth.hfToken.name "${VALUES_PATH}")
    HF_KEY=$(yq -r .sampleApplication.model.auth.hfToken.key  "${VALUES_PATH}")
    $KCMD delete secret "${HF_NAME}" -n "${NAMESPACE}" --ignore-not-found
    $KCMD create secret generic "${HF_NAME}" \
        --namespace "${NAMESPACE}" \
        --from-literal="${HF_KEY}=${HF_TOKEN}" \
        --dry-run=client -o yaml | $KCMD apply -n "${NAMESPACE}" -f -
    log_success "HF token secret created"
}
