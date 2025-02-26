#!/bin/bash

set -e

# Get latest runner version if not specified
if [ -z "$1" ]; then
    echo "No version specified, detecting latest runner version..."
    if ! command -v gh &> /dev/null; then
        echo "GitHub CLI (gh) not found. Please install it or specify a version manually."
        echo "Usage: $0 [VERSION]"
        exit 1
    fi
    
    RUNNER_VERSION=$(gh api repos/actions/runner/releases/latest --jq .tag_name | sed 's/^v//')
    if [ -z "$RUNNER_VERSION" ]; then
        echo "Error: Failed to retrieve latest runner version"
        exit 1
    fi
else
    RUNNER_VERSION="$1"
fi

echo "Building actions runner image for version: $RUNNER_VERSION"

# Get current user UID and docker GID
OWNER_UID=$(id -u)
DOCKER_GID=$(getent group docker | cut -d: -f3)

if [ -z "$DOCKER_GID" ]; then
    echo "Warning: Docker group not found. Using default GID 999"
    DOCKER_GID=999
fi

echo "Using UID: $OWNER_UID and Docker GID: $DOCKER_GID"

# Build multi-architecture image
echo "Building multi-architecture image actions-runner:$RUNNER_VERSION..."
docker buildx build --progress=plain \
    --build-arg RUNNER_VERSION=$RUNNER_VERSION \
    --build-arg OWNER_UID=$OWNER_UID \
    --build-arg DOCKER_GID=$DOCKER_GID \
    -t actions-runner:$RUNNER_VERSION \
    --load \
    .

echo "Image actions-runner:$RUNNER_VERSION built successfully"
echo "You can now use config-generator.sh to create runner configurations"
