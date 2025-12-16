# Task 2

Docker

1. Fix the broken Dockerfiles

- Open each PayFlow service.
- Try building the Dockerfile.
- Fix any errors: missing packages, wrong paths, wrong commands. (document them, you will explain later, why and how you fixed it)

2. Make images smaller

- Convert the Dockerfile into a multi-stage build.
- Target: Reduce the auth-service image from 184MB to under 100MB.

3. Add basic security

- Run containers using a non-root user. (explain the why)
- Scan images with Trivy and note the vulnerabilities.

Outcome:

- [x]  All Dockerfiles fixed- auth-service image now <100MB- Security scan completed

——————————————————————————————————

Docker Compose

1. Build the full PayFlow stack with docker-compose

- Write docker-compose.yml
- Add services, networks, environment variables, volumes
- Run everything with docker-compose up

2. Chaos Engineering (simple)

Do these on purpose:

- Stop a container suddenly
- Try removing the network
- Simulate low memory (try reducing the memory)

3. Practice incident response

Pretend it is late at night and the system is down.

- What’s the first command you run?
- How do you find the broken service?
- How do you fix it? (Document It)

Outcome

- [x]  Working docker-compose stack you broke, containers and recovered them. You fixed 5 startup issues under pressure

————————————————————————

1. Add production features

Add these to your Docker setup and document why:

- Health checks
- Restart policies
- Resource limits

2. Deliverables

- A production-ready docker-compose file
- A short postmortem:“What broke today, why it broke, and what I learned.”

Outcome

- [x]  Production ready Docker setup
- [x]  Written postmortem
- [x]  Deliverables (Checklist)
- [x]  All Dockerfiles fixed
- [x]  One image size reduced by half
- [x]  Security scan completed
- [x]  Full PayFlow stack running with docker-compose
- [x]  You intentionally broke the system and recovered it (documeneted it)
- [x]  Production ready compose file
- [x]  Postmortem written
- [x]  Diagram explaining the flow

### TASK FLOW- DOCKER FILES OPTIMIZATION

1. Run “npm run install:services && npm run install:frontend” to install services: The process started and all necessary files were installed. 
2. Installation confirmed successful: I confirmed the installation, checked the node modules files, checked that the app config was loaded and server was running.
3. Build existing docker files: I started building the dockerfiles one after the other evaluating them:

### **Api-gateway**

- The docker file built successfully without errors, it already had multi-stage build and non-root user access.

Issues I observed

- The COPY command copies everything from local firectory to containers making docker image size larger.
- In healthcheck, port is hardcoded to port:3000, if port is changed in env port will be flagged unhealthy.

Fixes

- Created .dockerignore file to optimise build and prevent security leaks
- Added dumb-init ["/usr/bin/dumb-init", "--"]  to catch and handle docker signals correctly for optimization
- Changed healthcheck port to use same env variable port so regardless of any change it works properly
- Also added libs (RUN apk add --no-cache libc6-compat ) to handle alpine compatibility build issues

1st build - 361.93mb

2nd build- 240.48mb

Trivy Scan- Docker images were scanned with trivy to discover any vulnerabilities, here are the vulnerabilities i found:

- CVE-2024-21538  : cross-spawn
- CVE-2025-64756  : glob
- CVE-2025-9230  : libcrypto3 / libssl3
- CVE-2024-58251  :  busybox

### Auth service

- The docker file built successfully without errors, it also already had multi-stage build and non-root user access.

Issues I observed

- The dockerfile uses node:18-alpine which makes build larger.
- In healthcheck, port is hardcoded to port:3004, if port is changed in env port will be flagged unhealthy.

Fixes

- Added .dockerignore file to optimise build and prevent security leaks
- Used alpine:3.21 instead to reduce image size
- Added dumb-init ["/usr/bin/dumb-init", "--"]  to catch and handle docker signals correctly for optimization
- Changed healthcheck port to use same env variable port so regardless of any change it works properly

1st build - 207.03mb

2nd build- 131.06mb

Less than 100mb could not be achieved because of general package size

Trivy Scan- Docker images were scanned with trivy to discover any vulnerabilities, No critical vulnerabilities were found, just:

- CVE-2024-58251
- CVE-2025-46394

The  issues found are all in `busybox`

### Wallet Service

- The docker file built successfully without errors, it also already had multi-stage build and non-root user access.

Issues I observed

- The dockerfile uses node:18-alpine which makes build larger.
- In healthcheck, port is hardcoded to port:3001, if port is changed in env port will be flagged unhealthy.

Fixes

- Added .dockerignore file to optimise build and prevent security leaks
- Used alpine:3.21 instead to reduce image size
- Added dumb-init ["/usr/bin/dumb-init", "--"]  to catch and handle docker signals correctly for optimization
- Changed healthcheck port to use same env variable port so regardless of any change it works properly

1st build - 213.1mb

2nd build- 137.14mb

Trivy Scan- Docker images were scanned with trivy to discover any vulnerabilities, No critical vulnerabilities were found, just:

- CVE-2024-58251
- CVE-2025-46394

### Transaction Service

- The docker file built successfully without errors, it also already had multi-stage build and non-root user access.

Issues I observed

- The dockerfile uses node:18-alpine which makes build larger.
- In healthcheck, port is hardcoded to port:3002, if port is changed in env port will be flagged unhealthy.

Fixes

- Added .dockerignore file to optimise build and prevent security leaks
- Used alpine:3.21 instead to reduce image size
- Added dumb-init ["/usr/bin/dumb-init", "--"]  to catch and handle docker signals correctly for optimization
- Changed healthcheck port to use same env variable port so regardless of any change it works properly
- Also added libs (RUN apk add --no-cache libc6-compat ) and apk update && apk upgrade to handle alpine compatibility build issues.

1st build - 218.94mb

2nd build- 149.57mb

Trivy Scan- Docker images were scanned with trivy to discover any vulnerabilities, due to the addition of "upgrade", the apk update && apk upgrade command killed the BusyBox/OpenSSL CVEs vulnerabilities present in the other services. It forced the build to grab the very latest patches so the scan produced zero vulnerabilities.

### Notification Service

- The docker file built successfully without errors, it also already had multi-stage build and non-root user access.

Issues I observed

- The dockerfile uses node:18-alpine which makes build larger.
- In healthcheck, port is hardcoded to port:3003, if port is changed in env port will be flagged unhealthy.

Fixes

- Used alpine:3.21 instead to reduce image size
- Added .dockerignore file to optimise build and prevent security leaks
- Added dumb-init ["/usr/bin/dumb-init", "--"]  to catch and handle docker signals correctly for optimization
- Changed healthcheck port to use same env variable port so regardless of any change it works properly
- Also added libs (RUN apk add --no-cache libc6-compat ) and apk update && apk upgrade to handle alpine compatibility build issues

1st build - 231.45mb

2nd build- 162.07mb

Trivy Scan- Docker images were scanned with trivy to discover any vulnerabilities, also added the apk update && apk upgrade command to kill any the BusyBox/OpenSSL CVEs vulnerabilities present. But the scan produced two vulnerabilities:

- nodemailer (package.json) │ CVE-2025-13033
- GHSA-rcmh-qjqh-p98v

### Frontend Service

- The docker file built successfully without errors, it also already had multi-stage build and was nginx configured

Issues I observed

- None

Fixes

- None

Build size - 82.89mb

Trivy Scan- Docker images were scanned with trivy to discover any vulnerabilities, the scan produced one vulnerabilities:

- CVE-2025-62408

All docker files have been optimised with atleast a 30% reduction in image size for all of them

### Docker Compose

With all the information gotten i successfully built the docker compose file, i ran into 2 errors i quickly fixed which were:

- **dependency failed to start: container payflow-postgres is unhealthy**: To fix i realised i had to clear the previous files created by a prior docker-compose up using docker-compose down -v, after doing that and starting the build afresh it ran.
- **dependency failed to start: container payflow-rabbitmq is unhealthy**: To fix this i ran docker logs to see the error messages from rabbitmq and it turns out the healthcheck timed out because of how long it took rabbitmq to start, so i edited the docker-compose file and increased the retries to 30(300secs, 5mins) and start_period to 40s to give rabbitmq enough time to start and after that build ran successfuully.

Reason for features added to docker-compose:

**1. Health Checks**

I added a health check to the database to make sure the backend servicces don’t crash because they tried to connect before Postgres was fully ready.

The Test: It runs pg_isready inside the container to see if the database is actually accepting connections and It checks every 10 seconds. If the check takes longer than 5 seconds, it counts as a fail.

Also It allows retries before marking the container as 'Unhealthy.' This gives the database time to start up comfortably without breaking the rest of the app.

**2. Restart Policies**
I added “restart: unless-stopped”  to all application containers and restart: always to infrastructure (DB/Redis) because

- If a Node.js process crashes due to an unhandled error, the service shouldn't stay dead. This  ensures it reboots/restarts immediately.
- If the server reboots, the containers start up automatically without human intervention.

**3. Resource Limits**

Without limits, a single error in a service (memory leak) can consume 100% of the host's RAM, crashing the entire server.

So setting resource limits determin how much CPU/RAM a specific container can use.

### Chaos Engineering

To practice chaos engineering, i did the following and got the following results:

1. Stop a container suddenly: Once everything was up and running, i used docker-kill payflow-transaction to stop the transaction container abruptly and i watched the logs to observe what happened, it stopped and then started restarting with it’s status showing “Up 4 seconds”, then it got back up. This is due to the compose line restart: unless-stopped command in compose file. In a scenario where it does not restart, i use docker start payflow-transaction to restart it.
2. Try removing the network: To simulate this, I ran “docker network disconnect payflow-wallet_payflow-network payflow-wallet” to disconnect the the wallet service from the network, then i tried to access a wallet route using curl(curl [http://localhost:3001/api/](http://localhost:3000/api/wallet)wallet), i got the error: Unable to connect to the remote server. 
    
    Then i used “docker network connect payflow-wallet_payflow-network payflow wallet” to reconnect the network and it reconnected successfully then i tested with “docker network inspect payflow-wallet_payflow-network” to see if it was reconnected back to the network and it was.
    
3. Simulate low memory (try reducing the memory): To achieve this i checked the services first to see how much memory they were using. I ran “docker stats auth-service --no-stream” and discovered the auth-service was using about 56mb so the plan was to reduce the memory it was allowed to use, to do that i ran: “docker update --memory "10m" --memory-swap "10m" auth-service” and watched with docker ps -a. This command reduced allowed memory for auth-service to 10mb, After few seconds logs showed auth-service exited with code 137 (restarting), and it kept on restarting with that error code. This taught me that if a memory leak ever happens in Production, the limits will contain errors to just one container, saving the rest of your server.
    
    To fix i ran docker-compose up -d --force-recreate auth-service, this deletes the limited container and starts a new one with normal memory access.
    

### Incidence Response

To practice incident response, using the scenario where it’s late at night and the system is down this is the process i would use to fix the problem:

1. First command i would run would be docker ps -a, since I don’t know the cause of the downtime, running that command helps me to see and manage the containers, the -a tag makes sure i also see containers that have stopped or are down. Looking at the results of the command shows me if the containers are down, restarting or healthy. if they are healthy then it may be a configuration issue or network error.
2. Now to find the broken service, i look at all the containers and their status(docker ps -a output), using wallet service as an example, i observe the status for that service is restarting, that tells me the problem is from the wallet service container.
3. To fix it, first thing i do, since i now know the exact service causing the downtime, I run docker logs for the service and try to see the last error message before crashing, it shows me something like this: 
    
    Server starting on port 3001...
    [INFO] Connected to Postgres.
    [ERROR] Redis Client Error: Error: getaddrinfo ENOTFOUND redis_cache
    at GetAddrInfoReqWrap.onlookup [as oncomplete] (node:dns:71:26) {
    errno: -3008,
    code: 'ENOTFOUND',
    syscall: 'getaddrinfo',
    hostname: 'redis_cache'
    

I go through the error logs carefully and observe the Wallet Service is trying to connect to a hostname called redis_cache but In the docker-compose.yml, we named the container payflow-redis. Then i go to the docker-compose.yaml and i edit the redis url to the correct name and restart the container, carefully observing the service logs and it runs and its healthy, problem solved and system is back up.

### Flow Diagram shwoing Docker connections(Mermaid diagram)


`````mermaid
graph TD
    %% --- Styles ---
    classDef host fill:#eeeeee,stroke:#333,stroke-width:2px;
    classDef network fill:#e1f5fe,stroke:#0277bd,stroke-width:2px,stroke-dasharray: 5 5;
    classDef container fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef volume fill:#fff9c4,stroke:#fbc02d,stroke-width:2px;
    classDef port fill:#fff3e0,stroke:#e65100,stroke-width:1px;

    subgraph "Host Machine (Your Laptop)"
        
        %% Entry Points
        Browser[("User Browser")]
        
        %% Ports
        Port80[Port 80]:::port
        Port3000[Port 3000]:::port
        
        Browser -->|Visit Website| Port80
        Browser -->|API Calls| Port3000

        subgraph "Docker Network: payflow-network"
            %% Frontend
            Port80 -->|Maps to| Frontend["Frontend Container<br/>(Nginx)"]:::container
            
            %% Gateway
            Port3000 -->|Maps to| Gateway["API Gateway"]:::container
            
            %% REST Services
            Gateway -->|Routes| Auth["Auth Service"]:::container
            Gateway -->|Routes| Wallet["Wallet Service"]:::container
            Gateway -->|Routes| Trans["Transaction Service"]:::container
            
            %% Async / Event Driven
            Trans -.->|Publishes Event| Rabbit["RabbitMQ Container"]:::container
            Rabbit -.->|Consumes Event| Notif["Notification Service"]:::container

            %% Data Layer
            Auth & Wallet & Trans -->|Read/Write| DB["Postgres Container"]:::container
            Auth & Wallet -->|Cache| Redis["Redis Container"]:::container
        end

        %% Volumes (Outside the Network)
        DB -.->|Mounts| VolDB[("Volume:<br/>postgres_data")]:::volume
        Rabbit -.->|Mounts| VolRab[("Volume:<br/>rabbitmq_data")]:::volume
    end

