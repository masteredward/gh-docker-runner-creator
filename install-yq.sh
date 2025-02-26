#!/bin/bash

# Get the latest version number
VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
echo "Latest version: $VERSION"

# Download the binary for your architecture
BINARY="yq_linux_amd64"
curl -L https://github.com/mikefarah/yq/releases/download/v${VERSION}/${BINARY} -o /tmp/yq

# Make it executable
chmod +x /tmp/yq

# Move to a directory in PATH
sudo mv /tmp/yq /usr/local/bin/yq

# Verify installation
echo "Installed yq version:"
yq --version