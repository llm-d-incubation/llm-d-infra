#!/bin/bash

usage() {
  cat <<EOF
Usage: $(basename "$0") <bump_type>

Bumps the Helm chart version in Chart.yaml by the specified type.

Required argument:
  bump_type     The type of version bump. Must be one of:
                  - major
                  - minor
                  - patch

Examples:
  $(basename "$0") patch     # 1.2.3 -> 1.2.4
  $(basename "$0") minor     # 1.2.3 -> 1.3.0
  $(basename "$0") major     # 1.2.3 -> 2.0.0

EOF
  exit 1
}

BUMP_TYPE="$1"

if [[ -z "${BUMP_TYPE}" ]]; then
  echo -e "Error: no \$bump_type passed as \$1.\n"
  usage
elif [[ "${BUMP_TYPE}" != "major" ]] && [[ "${BUMP_TYPE}" != "minor" ]] && [[ "${BUMP_TYPE}" != "patch" ]]; then
  echo -e "Error: \$bump_type \"${BUMP_TYPE}\" not recognized.\n"
  usage
fi

# requires git, yq

REPO_ROOT=$(git rev-parse --show-toplevel)

# Path to your Chart.yaml
CHART_FILE="${REPO_ROOT}/charts/llm-d-infra/Chart.yaml"

FEATURE_BRANCH=$(git rev-parse --abbrev-ref HEAD)

STASH_RESULT=$(git stash)

git fetch upstream
git checkout main
git merge --ff-only upstream/main

git switch ${FEATURE_BRANCH}
if [[ "${STASH_RESULT}" != "No local changes to save" ]]; then
  git stash pop
fi;

git checkout main -- ${CHART_FILE}

current_version=$(yq e '.version' "$CHART_FILE")

IFS='.' read -r major minor patch <<< "$current_version"

if [[ "${BUMP_TYPE}" == "patch" ]]; then
  patch=$((patch + 1))
elif [[ "${BUMP_TYPE}" == "minor" ]]; then
  minor=$((minor + 1))
  patch=0
elif [[ "${BUMP_TYPE}" == "major" ]]; then
  major=$((major + 1))
  minor=0
  patch=0
fi

new_version="$major.$minor.$patch"

yq e -i ".version = \"$new_version\"" "$CHART_FILE"

echo "Version updated: $current_version → $new_version"

pre-commit run -a
