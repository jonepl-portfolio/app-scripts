# Use the Docker-in-Docker image as the base image
FROM docker:20.10-dind

# Install any additional tools you might need in the remote server container
RUN apk update && apk add --no-cache curl wget make bash

# Create working directory and copy files needed for your server
COPY . /srv/app/
RUN chmod +x /srv/app/start-apps.local.sh
RUN chmod +x /srv/app/site-reliability-tools/security/certbot.local.sh
RUN mkdir -p /srv/docker/certs/www/certbot/
RUN mkdir -p /srv/app/api-gateway/vhost.d/

# Expose default network port for web servers
EXPOSE 80
EXPOSE 443
EXPOSE 2375

# The Docker daemon will run as the primary process in the container
CMD ["dockerd-entrypoint.sh"]