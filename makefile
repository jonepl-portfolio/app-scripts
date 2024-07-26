build-server:
	docker build -t mock-server:latest .
	docker image prune -f

run-server:
	docker-compose up -d
	sleep 3
	docker exec -it $$(docker ps -qf "name=mock-server") /bin/bash /srv/app/app-scripts/start-apps.local.sh

start-server: run-server

stop-server:
	docker-compose down

destroy-server: stop-server

ssh-server:
	docker exec -it mock-server sh

remove-swarm:
	$(MAKE) remove-services
	$(MAKE) remove-config
	$(MAKE) remove-network
	$(MAKE) remove-volume
	$(MAKE) leave-swarm

remove-network:
	@if [ -n "$$(docker network ls -f name=portfolio-network --format '{{.ID}}')" ]; then \
		echo "Removing existing network: portfolio-network..."; \
		docker network rm $$(docker network ls -f name=portfolio-network --format '{{.ID}}'); \
	else \
		echo "Network 'portfolio-network' does not exist."; \
	fi

remove-config:
	@if [ -n "$$(docker config ls -f name=gateway-config --format '{{.ID}}')" ]; then \
		echo "Removing existing config: gateway-config..."; \
		docker config rm $$(docker config ls -f name=gateway-config --format '{{.ID}}'); \
	else \
		echo "Config 'gateway-config' does not exist."; \
	fi

remove-volume:
	@if [ -n "$$(docker volume ls -f name=nginx_certs --format '{{.ID}}')" ]; then \
		echo "Removing existing config: nginx_certs..."; \
		docker config rm $$(docker config ls -f name=nginx_certs --format '{{.ID}}'); \
	else \
		echo "Config 'nginx_certs' does not exist."; \
	fi

	@if [ -n "$$(docker volume ls -f name=certbot_config --format '{{.ID}}')" ]; then \
		echo "Removing existing config: certbot_config..."; \
		docker config rm $$(docker config ls -f name=certbot_config --format '{{.ID}}'); \
	else \
		echo "Config 'certbot_config' does not exist."; \
	fi

remove-api-gateway:
	docker service rm $(shell docker service ls -f name=hosted-apps_nginx --format "{{.ID}}")

remove-csv-merger-api:
	docker service rm $(shell docker service ls -f name=hosted-apps_csv-merger --format "{{.ID}}")

remove-web-portfolio:
	docker service rm $(shell docker service ls -f name=hosted-apps_web-portfolio --format "{{.ID}}")

remove-services:
	@if [ -n "$$(docker service ls --format '{{.ID}}')" ]; then \
		echo "Removing all running services..."; \
		docker service rm $$(docker service ls --format '{{.ID}}'); \
	else \
		echo "No running services to remove."; \
	fi

leave-swarm:
	docker swarm leave -f

