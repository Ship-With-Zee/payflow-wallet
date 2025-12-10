Payflow Wallet Task

Draw the Architecture

- Diagram should include: Auth, Wallet, Transaction, Notification, API Gateway, Frontend, DB, Redis, rabbitmq.

— Explain Each Service

- For each service: purpose, port, env vars, dependencies (other services/DB/cache).

— Full Request Trace

- Trace “Send Money” end to end with notes + sequence diagram.

### Steps taken to achieve task, process and documentation

### 1. Read codebase and understand the database schema: Doing this ensures i understand the project model and service endpoints.

List table name and services connected from migrations:

```
Table Name     | Columns (key ones)           | Owned By Service
---------------|------------------------------|------------------
users          | id, email, password_hash     | auth-service
wallets        | id, balance, currency         | wallet-service
transactions   | id, from_userid, to_userid, amount, error-message| transaction-service
notification   | id, userid, transaction_id        | notification-service
```

### 2. Read .env.example to get port numbers for each service:

Port numbers and services-
```
AUTH_SERVICE_URL=http://auth-service:3004
WALLET_SERVICE_URL=http://wallet-service:3001
TRANSACTION_SERVICE_URL=http://transaction-service:3002
NOTIFICATION_SERVICE_URL=http://notification-service:3003
REDIS_URL=redis://redis:6379
DB_PORT=5432
RABBITMQ_URL=amqp://payflow:payflow123@rabbitmq:5672
```
