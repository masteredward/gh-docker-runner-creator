#!/bin/bash
set -e

# Runner directories
INSTALL_DIR="/runner-installation"
RUNTIME_DIR="/actions-runner"
CONFIG_DIR="${RUNTIME_DIR}/.runner"

# Check if we need to copy files from installation directory to runtime directory
if [ ! -f "${RUNTIME_DIR}/config.sh" ]; then
    echo "Initializing runner directory with required files..."
    cp -a ${INSTALL_DIR}/* ${RUNTIME_DIR}/
fi

# Change to runtime directory for all operations
cd ${RUNTIME_DIR}

# Check if this is the first run (no config yet)
if [ ! -f "${CONFIG_DIR}/config.json" ]; then
    # Validate required environment variables
    if [ -z "${REPO_URL}" ] || [ -z "${RUNNER_TOKEN}" ] || [ -z "${RUNNER_NAME}" ]; then
        echo "Error: First run requires REPO_URL, RUNNER_TOKEN, and RUNNER_NAME environment variables"
        echo "Usage: docker run -e REPO_URL=https://github.com/owner/repo -e RUNNER_TOKEN=token -e RUNNER_NAME=name actions-runner:version"
        exit 1
    fi
    
    echo "First time configuration for runner ${RUNNER_NAME}"
    echo "Configuring runner for repository: ${REPO_URL}"
    
    # Configure the runner
    ./config.sh --unattended \
        --url "${REPO_URL}" \
        --token "${RUNNER_TOKEN}" \
        --name "${RUNNER_NAME}" \
        --work _work
        
    echo "Runner configured successfully"
else
    echo "Runner already configured, reusing existing configuration"
fi

# Remove any previous run.pid file that might exist
if [ -f "${RUNTIME_DIR}/run.pid" ]; then
    rm -f ${RUNTIME_DIR}/run.pid
fi

# Start the runner
echo "Starting runner..."
./run.sh
