#!/usr/bin/env bash
# -*- indent-tabs-mode: nil; tab-width: 4; sh-indentation: 4; -*-

set -euo pipefail

# Determine OS and architecture
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64) ARCH="amd64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Helper: install via package manager or brew if available
install_pkg() {
  PKG="$1"
  if [[ "$OS" == "linux" ]]; then
    if command -v apt &> /dev/null; then
      sudo apt-get install -y "$PKG"
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y "$PKG"
    elif command -v yum &> /dev/null; then
      sudo yum install -y "$PKG"
    else
      echo "Unsupported Linux distro (no apt, dnf, or yum).";
      exit 1
    fi
  elif [[ "$OS" == "darwin" ]]; then
    if command -v brew &> /dev/null; then
      brew install "$PKG"
    else
      echo "Homebrew not found. Please install Homebrew or add manual install logic.";
      exit 1
    fi
  else
    echo "Unsupported OS: $OS";
    exit 1
  fi
}

# Install base utilities
for pkg in git jq curl tar wget; do
  if ! command -v "$pkg" &> /dev/null; then
    install_pkg "$pkg"
  fi
done

# Install yq (v4+)
if ! command -v yq &> /dev/null; then
  echo "Installing yq..."
  if [[ "$OS" == "linux" ]]; then
    sudo wget -qO /usr/local/bin/yq \
      https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}
  else  # macOS
    sudo wget -qO /usr/local/bin/yq \
      https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_${ARCH}
  fi
  sudo chmod +x /usr/local/bin/yq
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  K8S_URL="https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -LO "${K8S_URL}/bin/${OS}/${ARCH}/kubectl"
  if [[ "$OS" == "darwin" ]]; then
    sudo install -m 0755 kubectl /usr/local/bin/kubectl
  else
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  fi
  rm kubectl
fi

# Install Helm
if ! command -v helm &> /dev/null; then
  echo "Installing Helm..."
  HELM_VER="v3.17.3"
  TARBALL="helm-${HELM_VER}-${OS}-${ARCH}.tar.gz"
  wget "https://get.helm.sh/${TARBALL}"
  tar -zxvf "${TARBALL}"
  sudo mv "${OS}-${ARCH}/helm" /usr/local/bin/helm
  rm -rf "${OS}-${ARCH}" "${TARBALL}"
fi

# Install Helmfile

if ! command -v helmfile &> /dev/null; then
  echo "📦 helmfile not found. Installing..."
  HELMFILE_VERSION="v0.162.0"
  HELMFILE_URL="https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${OS}_${ARCH}"
  INSTALL_DIR="/usr/local/bin"
  curl -fsSL -o "/tmp/helmfile" "$HELMFILE_URL"
  chmod +x "${INSTALL_DIR}/helmfile"
fi

# Install kustomize
if ! command -v kustomize &> /dev/null; then
  echo "Installing Kustomize..."
  KUSTOMIZE_TAG=$(curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | jq -r '.tag_name')
  VERSION_NUM=${KUSTOMIZE_TAG#kustomize/}
  ARCHIVE="kustomize_${VERSION_NUM}_${OS}_${ARCH}.tar.gz"
  curl -sLo kustomize.tar.gz \
    "https://github.com/kubernetes-sigs/kustomize/releases/download/${KUSTOMIZE_TAG}/${ARCHIVE}"
  tar -xzf kustomize.tar.gz
  sudo mv kustomize /usr/local/bin/
  rm kustomize.tar.gz
fi

# Install helmfile

echo "All tools installed successfully."
