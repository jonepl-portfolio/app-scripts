for service in $(docker stack services hosted-apps --format '{{.Name}}'); do
  docker service update --force "$service"
done