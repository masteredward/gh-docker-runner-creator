#!/bin/bash

if command -v yq &> /dev/null; then
    echo "yq is already installed"
    exit 0
fi

# Get the latest version number
VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
echo "Latest version: $VERSION"

# Download the binary for your architecture
if [[ "$(uname -m)" == "x86_64" ]]; then
    BINARY="yq_linux_amd64"
elif [[ "$(uname -m)" == "aarch64" ]]; then
    BINARY="yq_linux_arm64"
else
    echo "Unsupported architecture: $(uname -m)"
    exit 1
fi

sudo curl -L https://github.com/mikefarah/yq/releases/download/v${VERSION}/${BINARY} -o /usr/local/bin/yq

# Make it executable
chmod +x /usr/local/bin/yq

# Verify installation
echo "Installed yq version:"
yq --version