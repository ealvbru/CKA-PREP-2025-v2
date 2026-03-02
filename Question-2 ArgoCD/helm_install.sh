#!/bin/bash

set -e

HELM_INSTALL_DIR="/usr/local/bin"
TMP_DIR=$(mktemp -d)

echo "Detecting architecture..."
ARCH=$(uname -m)

case $ARCH in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Architecture: $ARCH"

echo "Fetching latest Helm version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4)

if [ -z "$LATEST_VERSION" ]; then
  echo "Failed to fetch latest version."
  exit 1
fi

echo "Latest Helm version: $LATEST_VERSION"

cd "$TMP_DIR"

echo "Downloading Helm..."
curl -LO "https://get.helm.sh/helm-${LATEST_VERSION}-linux-${ARCH}.tar.gz"
curl -LO "https://get.helm.sh/helm-${LATEST_VERSION}-linux-${ARCH}.tar.gz.sha256"

echo "Verifying checksum..."
sha256sum -c "helm-${LATEST_VERSION}-linux-${ARCH}.tar.gz.sha256"

echo "Extracting..."
tar -xzf "helm-${LATEST_VERSION}-linux-${ARCH}.tar.gz"

echo "Installing to $HELM_INSTALL_DIR ..."
sudo mv "linux-${ARCH}/helm" "$HELM_INSTALL_DIR/helm"
sudo chmod +x "$HELM_INSTALL_DIR/helm"

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "Helm installed successfully!"
helm version
