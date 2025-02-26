#!/bin/bash
set -e

# Runner directories
INSTALL_DIR="/runner-installation"
RUNTIME_DIR="/actions-runner"
CONFIG_DIR="${RUNTIME_DIR}/.runner"

# Change to runtime directory for all operations
cd ${RUNTIME_DIR}

# Check if runtime directory is empty for first deployment
if [ -z "$(ls -A ${RUNTIME_DIR})" ]; then
    echo "Initializing empty runner directory with required files..."
    cp -a ${INSTALL_DIR}/* ${RUNTIME_DIR}/
    
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
