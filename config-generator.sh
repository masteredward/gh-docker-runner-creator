#!/bin/bash

# Check if repository argument was provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 REPOSITORY_NAME [RUNNER_VERSION]"
    echo "REPOSITORY_NAME can be in format 'repo' or 'owner/repo'"
    echo "RUNNER_VERSION is the version of the runner image to use (optional)"
    exit 1
fi

REPO_ARGUMENT="$1"
RUNNER_VERSION="$2"

# Parse repository name for directory check
if [[ "$REPO_ARGUMENT" == */* ]]; then
    REPO_NAME=$(echo "$REPO_ARGUMENT" | cut -d'/' -f2)
else
    REPO_NAME="$REPO_ARGUMENT"
fi

# Check if runner directory exists and is not empty
RUNNER_DIR="runners/${REPO_NAME}-runner"
if [ -d "$RUNNER_DIR" ] && [ "$(ls -A "$RUNNER_DIR" 2>/dev/null)" ]; then
    echo "Error: Runner directory $RUNNER_DIR already exists and is not empty."
    echo "This could indicate that a runner is already configured for this repository."
    echo "If you want to recreate the runner, please remove the directory first:"
    echo "  rm -rf $RUNNER_DIR"
    exit 1
fi

# Check for runner version
if [ -z "$RUNNER_VERSION" ]; then
    echo "No runner version specified, detecting latest runner version..."
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI (gh) is not installed or not in PATH"
        exit 1
    fi
    
    RUNNER_VERSION=$(gh api repos/actions/runner/releases/latest --jq .tag_name | sed 's/^v//')
    if [ -z "$RUNNER_VERSION" ]; then
        echo "Error: Failed to retrieve latest runner version"
        exit 1
    fi
    
    echo "Using latest runner version: $RUNNER_VERSION"
fi

# Check if the specified image exists
if ! docker image inspect actions-runner:$RUNNER_VERSION &>/dev/null; then
    echo "Error: Image actions-runner:$RUNNER_VERSION not found"
    echo "Please build it first using: ./build-runner-image.sh $RUNNER_VERSION"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed or not in PATH"
    exit 1
fi

# Check if gh is authenticated
echo "Verifying GitHub authentication..."
if ! gh auth status 2>/dev/null; then
    echo "Error: Not authenticated with GitHub CLI. Please run 'gh auth login'"
    exit 1
fi

# Get authenticated GitHub username
USERNAME=$(gh api user -q '.login')
if [ -z "$USERNAME" ]; then
    echo "Error: Failed to retrieve GitHub username"
    exit 1
fi

echo "Authenticated as: $USERNAME"

# Parse repository argument into owner and repo name
if [[ "$REPO_ARGUMENT" == */* ]]; then
    # Format is owner/repo
    OWNER=$(echo "$REPO_ARGUMENT" | cut -d'/' -f1)
    REPO_NAME=$(echo "$REPO_ARGUMENT" | cut -d'/' -f2)
else
    # Format is just repo, assume current user is owner
    OWNER="$USERNAME"
    REPO_NAME="$REPO_ARGUMENT"
fi

# Check if repository exists and current user has admin access
echo "Verifying repository $OWNER/$REPO_NAME..."
if ! gh repo view "$OWNER/$REPO_NAME" --json 'name,owner' &> /dev/null; then
    echo "Error: Repository $OWNER/$REPO_NAME does not exist or you don't have access"
    exit 1
fi

# Verify the current user has admin access (needed for runner token)
ADMIN_PERMISSION=$(gh api "repos/$OWNER/$REPO_NAME/collaborators/$USERNAME/permission" --jq '.permission')

if [ "$ADMIN_PERMISSION" != "admin" ]; then
    echo "Error: You don't have admin permissions for $OWNER/$REPO_NAME"
    echo "Admin permissions are required to create runner tokens"
    exit 1
fi

echo "Repository $OWNER/$REPO_NAME verified with admin permissions"

# Get runner token
echo "Retrieving runner token..."
RUNNER_TOKEN=$(gh api -X POST "repos/$OWNER/$REPO_NAME/actions/runners/registration-token" --jq .token)

if [ -z "$RUNNER_TOKEN" ]; then
    echo "Error: Failed to retrieve runner token"
    exit 1
fi

# Create directory for runner configuration (will be needed for persistence)
mkdir -p "$RUNNER_DIR"

# Check if docker-compose.yaml exists
DOCKER_COMPOSE_FILE="docker-compose.yaml"
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Error: docker-compose.yaml not found"
    exit 1
fi

# Update or create service in docker-compose.yaml
SERVICE_NAME="${REPO_NAME}-runner"
echo "Updating docker-compose.yaml with service: $SERVICE_NAME"

# Check if yq is installed (needed for yaml manipulation)
if ! command -v yq &> /dev/null; then
    echo "Warning: yq not installed. Will use sed-based approach (less reliable)"
    
    # Create a temporary file with the new service configuration
    TEMP_SERVICE=$(mktemp)
    cat > "$TEMP_SERVICE" << EOF
  ${SERVICE_NAME}:
    image: actions-runner:${RUNNER_VERSION}
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./"$RUNNER_DIR":/actions-runner
    privileged: true
    restart: always
EOF

    # Check if service already exists in docker-compose.yaml
    if grep -q "^  ${SERVICE_NAME}:" "$DOCKER_COMPOSE_FILE"; then
        echo "Service $SERVICE_NAME already exists in docker-compose.yaml, updating..."
        # Create a new file without the existing service
        awk -v service="${SERVICE_NAME}" 'BEGIN{skip=0} /^  [a-zA-Z0-9_-]+:/{if ($1 == "  " service ":") skip=1; else skip=0} !skip{print}' "$DOCKER_COMPOSE_FILE" > "${DOCKER_COMPOSE_FILE}.new"
        
        # Find the line with "services:" to insert the new service after it
        SERVICE_LINE=$(grep -n "^services:" "${DOCKER_COMPOSE_FILE}.new" | cut -d: -f1)
        if [ -n "$SERVICE_LINE" ]; then
            head -n "$SERVICE_LINE" "${DOCKER_COMPOSE_FILE}.new" > "${DOCKER_COMPOSE_FILE}.tmp"
            cat "$TEMP_SERVICE" >> "${DOCKER_COMPOSE_FILE}.tmp"
            tail -n +$((SERVICE_LINE + 1)) "${DOCKER_COMPOSE_FILE}.new" >> "${DOCKER_COMPOSE_FILE}.tmp"
            mv "${DOCKER_COMPOSE_FILE}.tmp" "$DOCKER_COMPOSE_FILE"
            rm "${DOCKER_COMPOSE_FILE}.new"
        else
            echo "Error: Could not find 'services:' line in docker-compose.yaml"
            rm "${DOCKER_COMPOSE_FILE}.new"
            exit 1
        fi
    else
        echo "Adding new service $SERVICE_NAME to docker-compose.yaml..."
        # Find the line with "services:" to insert the new service after it
        SERVICE_LINE=$(grep -n "^services:" "$DOCKER_COMPOSE_FILE" | cut -d: -f1)
        if [ -n "$SERVICE_LINE" ]; then
            head -n "$SERVICE_LINE" "$DOCKER_COMPOSE_FILE" > "${DOCKER_COMPOSE_FILE}.new"
            cat "$TEMP_SERVICE" >> "${DOCKER_COMPOSE_FILE}.new"
            tail -n +$((SERVICE_LINE + 1)) "$DOCKER_COMPOSE_FILE" >> "${DOCKER_COMPOSE_FILE}.new"
            mv "${DOCKER_COMPOSE_FILE}.new" "$DOCKER_COMPOSE_FILE"
        else
            echo "Error: Could not find 'services:' line in docker-compose.yaml"
            exit 1
        fi
    fi
    
    rm "$TEMP_SERVICE"
else
    # Use yq to update docker-compose.yaml (more reliable)
    echo "Using yq to update docker-compose.yaml"
    
    # Create a temporary file for the updated docker-compose
    TMP_FILE=$(mktemp)
    
    # Update or create the service using yq
    yq e ".services.\"${SERVICE_NAME}\" = {
      \"image\": \"actions-runner:${RUNNER_VERSION}\",
      \"volumes\": [
        \"/var/run/docker.sock:/var/run/docker.sock\",
        \"./"$RUNNER_DIR":/actions-runner\"
      ],
      \"privileged\": true,
      \"restart\": \"always\"
    }" "$DOCKER_COMPOSE_FILE" > "$TMP_FILE"
    
    mv "$TMP_FILE" "$DOCKER_COMPOSE_FILE"
fi

echo "Success! Docker compose configuration updated for runner: ${SERVICE_NAME}"

# Start the runner with environment variables for first-time configuration
echo "Starting the runner with registration configuration..."
REPO_URL="https://github.com/$OWNER/$REPO_NAME"
RUNNER_NAME="${REPO_NAME}-runner"

echo "Starting runner $SERVICE_NAME first run in 5 seconds. Press Ctrl+C when the Listening for Jobs message is displayed."
sleep 5

# Run the service with environment variables using docker compose run
docker compose run \
  --name "${SERVICE_NAME}" \
  -e REPO_URL="$REPO_URL" \
  -e RUNNER_TOKEN="$RUNNER_TOKEN" \
  -e RUNNER_NAME="$RUNNER_NAME" \
  $SERVICE_NAME

docker stop $SERVICE_NAME &>/dev/null || true
docker rm -f $SERVICE_NAME &>/dev/null || true

echo "Runner stopped after initial setup. Sleeping 5 seconds before restarting it using docker compose up -d"
sleep 5

docker compose up -d $SERVICE_NAME

echo "Runner restarted and now managed by compose! You can view the runner status on GitHub at: https://github.com/$OWNER/$REPO_NAME/settings/actions/runners"