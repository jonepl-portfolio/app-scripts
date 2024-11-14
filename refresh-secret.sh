#!/bin/bash

# Define the secret name
SECRET_NAME="app_config"
NEW_SECRET_FILE="/srv/app/app-scripts/.env"
SERVICES=()

# Define the compose file paths for services that use the app_config secret
HOSTED_COMPOSE_PATHS=("/srv/app/api-gateway/docker-compose.yml")
SRE_COMPOSE_PATHS=("/srv/app/site-reliability-tools/security/docker-compose.yml")

log_message() {
  local level=$1
  local message=$2
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$timestamp [$level] $message"
}

for service in $(docker service ls --format "{{.ID}}"); do
  secrets=$(docker service inspect "$service" --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}')

  if [[ "$secrets" != "null" ]] && echo "$secrets" | grep -q "$SECRET_NAME"; then
      log_message "INFO" "Adding service $service to SERVICES array"
      SERVICES+=("$service")
  fi
done

# Check if there are services using the secret
if [ ${#SERVICES[@]} -eq 0 ]; then
  log_message "ERROR" "No services are using the $SECRET_NAME secret."
  exit 1
fi

log_message "INFO" "Found services using the $SECRET_NAME secret: ${SERVICES[@]}"

log_message "INFO" "Rotating secrets..."
# declare -A original_replicas
for service in "${SERVICES[@]}"; do
  docker service rm "$service"
done

# Remove the old app_config secret
log_message "INFO" "Removing old $SECRET_NAME secret..."
docker secret rm "$SECRET_NAME"

# Create the updated app_config secret with the new file
log_message "INFO" "Creating new $SECRET_NAME secret..."
docker secret create "$SECRET_NAME" "$NEW_SECRET_FILE"

for compose_path in "${HOSTED_COMPOSE_PATHS[@]}"; do
  log_message "INFO" "Deploying $compose_path..."
  docker stack deploy -c "$compose_path" hosted-apps
done

for compose_path in "${SRE_COMPOSE_PATHS[@]}"; do
  log_message "INFO" "Deploying $compose_path..."
  docker stack deploy -c "$compose_path" sre-tools
done

log_message "INFO" "Secret rotation complete."