#!/bin/bash
WORKING_DIR="/srv/app"
CURRENT_DIR=$(pwd)
$VHOST_DIR="$WORKING_DIR/api-gateway/vhost.d"

# Initial environment variables from .env file
initialize_env_vars() {
    if [ -e $ENV_CONFIG ]; then
        echo "Setting environment variables for $ENV_CONFIG file"
        set -o allexport
        . .env
        set +o allexport

        # Check for required variables
        REQUIRED_VARS=(DOMAIN)
        for VAR in "${REQUIRED_VARS[@]}"; do
            if [ -z "${!VAR}" ]; then
                echo "Error: $VAR is not set in $ENV_CONFIG"
                exit 1
            fi
        done

        echo "All required variables are set."
    else
        echo "No $ENV_CONFIG found."
        exit 1
    fi
}

# Initialize Swarm
initialize_swarm() {
    if ! docker info | grep -q "Swarm: active"; then
        echo "Docker Swarm is not initialized. Initializing now..."
        docker swarm init
    else
        echo "Docker Swarm is already initialized."
    fi
}

# Create Docker Swarm network
create_network() {
    # Create reverse proxy network
    if ! docker network ls | grep -q "portfolio-network"; then
        echo "Creating Docker overlay network 'portfolio-network'..."
        docker network create --driver overlay portfolio-network
        # docker network create --driver overlay --attachable portfolio-network
    else
        echo "Docker overlay network 'portfolio-network' already exists."
    fi

    # Create Portainer Agent network
    if ! docker network ls | grep -q "agent-network"; then
        echo "Creating Docker overlay network 'agent-network'..."
        docker network create --driver overlay agent-network
        # docker network create --driver overlay --attachable agent-network
    else
        echo "Docker overlay network 'agent-network' already exists."
    fi
}

# Create gateway config
create_config() {
    if ! docker config ls | grep -q "gateway-config"; then
        echo "Creating Docker Swarm config 'gateway-config'..."
        docker config create gateway-config api-gateway/.env
    else
        echo "Docker Swarm config 'gateway-config' already exists."
    fi
}

# Create gateway config
create_volume() {
    if ! docker volume ls | grep -q "nginx_certs"; then
        echo "Creating Docker Swarm volume 'nginx_certs'..."
        docker volume create nginx_certs
    else
        echo "Docker Swarm volume 'nginx_certs' already exists."
    fi

    if ! docker volume ls | grep -q "certbot_config"; then
        echo "Creating Docker Swarm volume 'certbot_config'..."
        docker volume create certbot_config
    else
        echo "Docker Swarm volume 'certbot_config' already exists."
    fi
}

# Start services
start_services() {
    echo "Deploying Services"
    mkdir -p $VHOST_DIR
    docker stack deploy -c csv-merger-api/docker-compose.yml -c web-portfolio/docker-compose.yml hosted-apps
    docker stack deploy -c site-reliability-tools/security/docker-compose.local.yml -c site-reliability-tools/maintenance/docker-compose.yml sre-tools
    docker stack deploy -c api-gateway/docker-compose.yml hosted-apps
}

wait_for_certbot() {
    local retries=15
    local count=0
    local sleep_time=5

    echo "Waiting for Certbot container to be ready..."

    while [ $count -lt $retries ]; do
        CERTBOT_CONTAINER_ID=$(docker ps -qf "name=certbot")

        if [ -n "$CERTBOT_CONTAINER_ID" ]; then
            echo "Certbot container is running with ID: $CERTBOT_CONTAINER_ID"
            return 0
        else
            echo "Certbot container is not ready yet. Waiting for $sleep_time seconds..."
            sleep $sleep_time
            count=$((count + 1))
        fi
    done

    echo "Certbot container did not become ready after $((retries * sleep_time)) seconds."
    return 1
}

# Copy certificates from Certbot to DinD container
copy_certs() {
    echo "Copying certificates from Certbot container to mock server (DinD) container..."

    # Get the Certbot container ID
    CERTBOT_CONTAINER_ID=$(docker ps -qf "name=certbot")
    # Define paths
    SELF_SIGNED_CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
    LOCAL_CERT="localhost.crt"
    LOCAL_CERT_KEY="localhost.key"
    DEST_PATH="/tmp/host-certs"

    # Ensure destination directory exists
    mkdir -p $DEST_PATH

    # Copy certificates from service container to mock server
    docker cp $CERTBOT_CONTAINER_ID:$SELF_SIGNED_CERT_PATH/$LOCAL_CERT $DEST_PATH/$LOCAL_CERT
    docker cp $CERTBOT_CONTAINER_ID:$SELF_SIGNED_CERT_PATH/$LOCAL_CERT_KEY $DEST_PATH/$LOCAL_CERT_KEY

    echo "Certificates copied successfully."
}

echo "Starting apps..."
cd $WORKING_DIR

initialize_env_vars

initialize_swarm

create_network

create_config

create_volume

start_services

# Wait for Certbot container to be ready before copying certificates
if wait_for_certbot; then
    copy_certs
else
    echo "Failed to copy certificates because Certbot container is not ready."
fi

cd $CURRENT_DIR
echo "Finished running script!"