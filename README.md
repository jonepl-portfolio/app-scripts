# Hosted Apps Scripts

This repository is responsible holding all scripts used to start and stop the docker swarm instance resources. Below is the folder structure:

```
app
|_ api-gateway/     # Not included in this repo
|_ csv-merger-api/  # Not included in this repo
|_ web-portfolio/   # Not included in this repo
|_ site-reliability-tools/  # Not included in this repo
|_ app-scripts/
    |_ init-swarm.sh
    |_ remove-swarm.sh
    |_ update-hosted-apps.sh
    |_ makefile
```

## Using a DinD (Docker in Docker) mock server

### Note
Dockerfile, makefile, docker-compose.yml and .dockerignore should be move to the parent folder of all 5 repos if you'd like to use the mock server

```shell
# Start container
$ make run-server

# Stop container
$ make stop-server

# Access available endpoints expose by mock server
$ curl -X GET http://127.0.0.1:5010/health
```

### Debugging Mock Server

```shell
# ssh into the mock server for debugging
$ make ssh-server
```

Debugging services
1. Update init-swarm.sh so that the network allows services to attach to it.
2. Run and attach a dummy service to check if other services are reachable through the network with the following commands

```shell
# ssh into the mock server
$ make ssh-server 

# Start the dummy server and connected it to the network
$ docker run -it --rm --network portfolio-network busybox sh

# Communicate to other services using the docker service name
$ wget -qO- http://{SERVICE_NAME}:{PORT}
```


```shell
# Build docker image
$ docker build -t mock-server -f server.dockerfile .

# Run your container
$ docker run --privileged --name server -d -p 8080:80 mock-server

# Remote into your outer docker container
$ docker exec -it testing sh

# Test your inner docker API is working with a CURL command
$ curl -X GET http://127.0.0.1:5010/health
```

# Rollbacks

TBA

## Remaining Work

* Application
    * ~~DNS~~
    * subdomains
* Maintenance
    * Memory Management
    * Application Log Monitoring (Elasticsearch, Logstash, Kibana)
* Security
    * ~~Certbot~~
    * System and Container management 
        - Portainer *****
        - Prometheus & Grafana 
    * Rate Limiting  ***
    * Load Balancing ***
    * Scaling and rolling updates *****
    * IP Whitelisting & Blacklisting
    * Firewall
    * How to keep software updated
    * Prevent Brute Force attacks (Fail2Ban)
    * Prevent DDOS attacks
* Improvements 
    * Bitbucket Pipelines
        - Validate SSH Script
        - Ensure all files are update on the server
