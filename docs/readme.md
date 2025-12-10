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