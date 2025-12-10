### Architecture Diagram showing Auth, Wallet, Transaction, Notification, API Gateway, Frontend, DB, Redis, rabbitmq.


graph TD
    %% Styling
    classDef client fill:#f9f,stroke:#333,stroke-width:2px;
    classDef gateway fill:#ff9,stroke:#333,stroke-width:2px;
    classDef service fill:#bbf,stroke:#333,stroke-width:2px;
    classDef infra fill:#ddd,stroke:#333,stroke-width:2px;

    %% Layer 1: Client
    subgraph Client_Layer [Client Layer]
        User((User)):::client
    end

    %% Layer 2: Entry Points
    subgraph Entry_Layer [Entry Points]
        Nginx[Frontend Container<br/>Nginx / React]:::gateway
        Gateway[API Gateway]:::gateway
    end

    %% Layer 3: Microservices
    subgraph Service_Layer [Microservices Layer]
        Auth[Auth Service<br/>Port: 3004]:::service
        Wallet[Wallet Service<br/>Port: 3001]:::service
        Trans[Transaction Service<br/>Port: 3002]:::service
        Notif[Notification Service<br/>Port: 3003]:::service
    end

    %% Layer 4: Infrastructure
    subgraph Infra_Layer [Infrastructure Layer]
        Redis[(Redis Cache)]:::infra
        RabbitMQ{RabbitMQ Broker}:::infra
        DB[(PostgreSQL<br/>Shared DB)]:::infra
    end

    %% Connections
    User -->|HTTPS| Nginx
    User -->|API Calls / JSON| Gateway
    
    %% Gateway Routing
    Gateway -->|/auth| Auth
    Gateway -->|/wallet| Wallet
    Gateway -->|/transactions| Trans
    
    %% Service-to-Service (Sync)
    Trans -->|HTTP POST /transfer| Wallet
    
    %% Service-to-Service (Async)
    Trans -.->|Pub: Transaction Complete| RabbitMQ
    RabbitMQ -.->|Sub: Consume Event| Notif
    
    %% Database Connections (Shared)
    Auth --> DB
    Wallet --> DB
    Trans --> DB
    Notif --> DB
    
    %% Redis Connections
    Auth --> Redis
    Wallet --> Redis
    Trans --> Redis