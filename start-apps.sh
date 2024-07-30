#!/bin/bash
APP_WORKING_DIR="/srv/app"
VHOST_DIR="$APP_WORKING_DIR/api-gateway/vhost.d"
ENV_CONFIG="$APP_WORKING_DIR/app-scripts/.env"
CURRENT_DIR=$(pwd)

# Initial environment variables from .env file
initialize_env_vars() {
    if [ -e $ENV_CONFIG ]; then
        echo "Setting environment variables for $ENV_CONFIG file"
        set -o allexport
        . $ENV_CONFIG
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
        docker network create --driver overlay --attachable portfolio-network
    else
        echo "Docker overlay network 'portfolio-network' already exists."
    fi

    # Create Portainer Agent network
    if ! docker network ls | grep -q "agent-network"; then
        echo "Creating Docker overlay network 'agent-network'..."
        docker network create --driver overlay --attachable agent-network
    else
        echo "Docker overlay network 'agent-network' already exists."
    fi
}

# Create volumes
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

    # Load environment variables and deploy CSV Merger API
    docker stack deploy -c $APP_WORKING_DIR/csv-merger-api/docker-compose.yml -c $APP_WORKING_DIR/web-portfolio/docker-compose.yml hosted-apps

    # Deploy Portainer
    docker stack deploy -c $APP_WORKING_DIR/site-reliability-tools/maintenance/docker-compose.yml sre-tools

    # Load environment variables and deploy API Gateway
    docker stack deploy -c $APP_WORKING_DIR/api-gateway/docker-compose.yml hosted-apps

    # Wait for API Gateway to be started before deploying Certbot
    # NOTE: This is done to prevent failures when new domains are added
    wait_for_api_gateway
    docker stack deploy -c $APP_WORKING_DIR/site-reliability-tools/security/docker-compose.yml sre-tools
}

wait_for_api_gateway() {
    echo "Waiting for API gateway to be up..."

    while ! curl -s --head  --request GET "$DOMAIN" | grep "301 Moved Permanently" > /dev/null; do
        echo "API gateway is not up yet. Waiting..."
        sleep 10
    done

    echo "API gateway is up. Proceeding with Certbot script."
}

create_secret() {
    docker secret create app_config $ENV_CONFIG
}

echo "Starting apps..."
cd $APP_WORKING_DIR

initialize_env_vars

initialize_swarm

create_network

create_config

create_volume

create_secret

start_services

cd $CURRENT_DIR
echo "Finished running script!"