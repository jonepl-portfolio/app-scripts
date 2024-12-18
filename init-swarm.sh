#!/bin/bash
APP_WORKING_DIR="/srv/app"
VHOST_DIR="$APP_WORKING_DIR/api-gateway/vhost.d"

SHARED_SECRET_PATH="$APP_WORKING_DIR/app-scripts/.env.secret"
MAIL_SERVER_DIR="$APP_WORKING_DIR/web-portfolio/mail-server"
MAIL_SERVER_CONFIG_PATH="$MAIL_SERVER_DIR/.env.config"
MAIL_SERVER_SECRET_PATH="$MAIL_SERVER_DIR/.env.secret"

CURRENT_DIR=$(pwd)

log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
}

# Initial environment variables from .env.secret file
initialize_env_vars() {
    if [ -e $SHARED_SECRET_PATH ]; then
        log_message "INFO" "Setting environment variables for $SHARED_SECRET_PATH file"
        set -o allexport
        . $SHARED_SECRET_PATH
        set +o allexport

        # Check for required variables
        REQUIRED_VARS=(DOMAIN)
        for VAR in "${REQUIRED_VARS[@]}"; do
            if [ -z "${!VAR}" ]; then
                log_message "ERROR" "$VAR is not set in $SHARED_SECRET_PATH"
                exit 1
            fi
        done

        log_message "INFO" "All required variables are set."
    else
        log_message "ERROR" "No $SHARED_SECRET_PATH found."
        exit 1
    fi
}

# Initialize Swarm
initialize_swarm() {
    if ! docker info | grep -q "Swarm: active"; then
        log_message "INFO" "Docker Swarm is not initialized. Initializing now..."
        docker swarm init
    else
        log_message "INFO" "Docker Swarm is already initialized."
    fi
}

# Create Docker Swarm network
create_network() {
    # Create reverse proxy network
    if ! docker network ls | grep -q "portfolio-network"; then
        log_message "INFO" "Creating Docker overlay network 'portfolio-network'..."
        docker network create --driver overlay --attachable portfolio-network
    else
        log_message "INFO" "Docker overlay network 'portfolio-network' already exists."
    fi

    # Create Portainer Agent network
    if ! docker network ls | grep -q "agent-network"; then
        log_message "INFO" "Creating Docker overlay network 'agent-network'..."
        docker network create --driver overlay --attachable agent-network
    else
        log_message "INFO" "Docker overlay network 'agent-network' already exists."
    fi
}

# Create volumes
create_volume() {
    if ! docker volume ls | grep -q "certbot_config"; then
        log_message "INFO" "Creating Docker Swarm volume 'certbot_config'..."
        docker volume create certbot_config
    else
        log_message "INFO" "Docker Swarm volume 'certbot_config' already exists."
    fi
}

# Start services
start_services() {
    log_message "INFO" "Deploying Services..."
    mkdir -p $VHOST_DIR

    log_message "INFO" "Deploying CSV merger API and web portfolio to hosted-apps stack..."
    docker stack deploy -c $APP_WORKING_DIR/csv-merger-api/docker-compose.yml -c $APP_WORKING_DIR/web-portfolio/docker-compose.yml hosted-apps

    log_message "INFO" "Deploying Certbot and Portainer to sre-tools stack..."
    docker stack deploy -c $APP_WORKING_DIR/site-reliability-tools/maintenance/docker-compose.yml sre-tools

    log_message "INFO" "Deploying API gateway to hosted-apps stack..."
    docker stack deploy -c $APP_WORKING_DIR/api-gateway/docker-compose.yml hosted-apps

    # Wait for API Gateway to be started before deploying Certbot
    # NOTE: This is done to prevent failures when new domains are added
    wait_for_api_gateway

    log_message "INFO" "Deploying Certbot to sre-tools stack..."
    docker stack deploy -c $APP_WORKING_DIR/site-reliability-tools/security/docker-compose.yml sre-tools
}

wait_for_api_gateway() {
    log_message "INFO" "Waiting for API gateway on $DOMAIN to be up..."

    while ! curl -s --head  --request GET "$DOMAIN" | grep "301 Moved Permanently" > /dev/null; do
        log_message "INFO" "API gateway is not up yet. Waiting..."
        sleep 10
    done

    log_message "INFO" "API gateway is up. Proceeding with Certbot script."
}

create_secret() {
    if ! docker secret ls | grep -q "shared_secret"; then
        log_message "INFO" "Creating Docker secret 'shared_secret'..."
        docker secret create shared_secret $SHARED_SECRET_PATH
    else
        log_message "INFO" "Docker secret 'shared_secret' already exists."
    fi

    if ! docker secret ls | grep -q "mail_server_secret"; then
        log_message "INFO" "Creating Docker secret 'mail_server_secret'..."
        docker secret create mail_server_secret $MAIL_SERVER_SECRET_PATH
    else
        log_message "INFO" "Docker secret 'mail_server_secret' already exists."
    fi
}

create_config() {
    if ! docker config ls | grep -q "mail_server_config"; then
        log_message "INFO" "Creating Docker config 'mail_server_config'..."
        docker config create mail_server_config $MAIL_SERVER_CONFIG_PATH
    else
        log_message "INFO" "Docker config 'mail_server_config' already exists."
    fi
}

log_message "INFO" "Starting apps..."
cd $APP_WORKING_DIR

initialize_env_vars

initialize_swarm

create_network

create_volume

create_secret

create_config

start_services

cd $CURRENT_DIR
log_message "INFO" "Finished running script!"