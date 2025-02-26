# GitHub Docker Runner Creator

A toolkit for easily deploying and managing multiple GitHub Actions self-hosted runners in Docker containers on a single host machine.

## Overview

This project provides a set of scripts to automate the creation and management of Docker-based GitHub Actions runners. It allows you to:

- Build Docker images with the GitHub Actions runner for multiple architectures
- Automatically register runners for your GitHub repositories
- Manage multiple runners for different repositories on a single host
- Securely handle runner registration tokens

## Prerequisites

- Docker and Docker Compose installed on your host machine
- GitHub CLI (`gh`) installed and authenticated
- Admin access to the GitHub repositories you want to create runners for
- For multi-architecture builds: Docker Buildx configured

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/gh-docker-runner-creator.git
   cd gh-docker-runner-creator
   ```

2. Make the scripts executable:
   ```bash
   chmod +x build-runner-image.sh config-generator.sh entrypoint.sh
   ```

3. Create a directory for runner data:
   ```bash
   mkdir -p runners
   ```

## Components

### 1. Dockerfile

The Dockerfile creates an image with the GitHub Actions runner installed. It:

- Uses Debian slim as the base
- Installs the GitHub Actions runner and its dependencies
- Sets up a non-root user with Docker access
- Configures the entrypoint script

### 2. build-runner-image.sh

This script builds the Docker image for the GitHub Actions runner:

```bash
./build-runner-image.sh [VERSION]
```

**Parameters:**
- `VERSION` (optional): Specific runner version to use (e.g., "2.322.0"). If omitted, the latest version will be detected automatically.

The script:
- Detects the latest runner version using GitHub API (if version not specified)
- Gets the current user's UID and Docker group's GID
- Builds the Docker image with architecture support for both amd64 and arm64
- Tags the image as `actions-runner:VERSION`

### 3. config-generator.sh

This script configures and starts a runner for a specific GitHub repository:

```bash
./config-generator.sh REPOSITORY_NAME [RUNNER_VERSION]
```

**Parameters:**
- `REPOSITORY_NAME`: The repository to create a runner for, in format `repo` or `owner/repo`
- `RUNNER_VERSION` (optional): Version of the runner image to use

The script:
- Verifies you have admin access to the specified repository
- Obtains a registration token from GitHub
- Updates the docker-compose.yaml file with a new service for your repository
- Creates necessary directories for runner persistence
- Starts the runner container with the required environment variables

### 4. entrypoint.sh

This script runs inside the container and:
- Checks if the runner is already configured
- If not configured, uses provided environment variables to register with GitHub
- Starts the runner process

### 5. docker-compose.yaml

Contains service definitions for all your runners. The config-generator script adds new services to this file.

## Usage Examples

### Creating a runner for your repository

1. First, build the runner image:
   ```bash
   ./build-runner-image.sh
   ```
   This detects the latest runner version and builds the image.

2. Create and start a runner for your repository:
   ```bash
   ./config-generator.sh your-username/your-repo
   ```

3. To create a runner for another repository:
   ```bash
   ./config-generator.sh another-repo
   ```

### Using a specific runner version

1. Build a specific version:
   ```bash
   ./build-runner-image.sh 2.320.0
   ```

2. Create a runner using that version:
   ```bash
   ./config-generator.sh your-repo 2.320.0
   ```

## How It Works

1. **Architecture**: 
   - Each repository gets its own runner container
   - Runner state is persisted in the `./runners/repo-name-runner` directory
   - Each runner connects to Docker via the Docker socket

2. **Security**:
   - Runner registration tokens are never stored on disk
   - Environment variables for registration are only used during the initial container start
   - Non-root user inside the container with access to Docker

3. **Lifecycle**:
   - First run: the runner registers with GitHub using the token
   - Subsequent runs: the runner reuses existing configuration
   - Container restarts automatically after system reboots

## Troubleshooting

### Runner fails to register

Check the logs of the runner:
```bash
docker logs repo-name-runner
```

### Issues with Docker access

Make sure the Docker socket is accessible:
```bash
ls -l /var/run/docker.sock
```
The Docker GID used in the container should match your host's Docker group.

### Registration token expired

Registration tokens expire after 1 hour. If you took too long between steps, generate a new configuration:
```bash
./config-generator.sh your-repo
```

## Advanced Configuration

### Organization-level runners

To create an organization-level runner, use:
```bash
./config-generator.sh org-name
```

### Labels and groups

To customize runner labels or groups, modify the entrypoint.sh script to add these parameters to the config.sh command.

### Custom work directories

By default, work directories are persisted in `./runners/repo-name-runner`. You can modify the paths in the docker-compose.yaml file if needed.

## License

This project is open source and available under the [GNU General Public License v3.0](LICENSE).
