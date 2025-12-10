### **Service explanations:**

Reviewed and went through server.js and package.json of each service to get dependencies and env_vars.

**AUTH SERVICE**

- **Purpose:** Validate tokens, issue refresh tokens, login and sign-out.
- **Port:** 3004
- **ENV VAR:** DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, REDIS_URL     **J**WT_SECRET
- **Dependencies:** bcrypt.js, cors, dotenv, express, express-rate-limit, express-validator, helmet, jsonwebtoken, morgan, pg, redis, winston

**WALLET SERVICE**

- **Purpose:** Manage balances, perform debits/credits
- **Port:** 3001
- **ENV VAR:** LOG_LEVEL, PROCESS.ENV, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD ****REDDIS_URL, DB_URL
- **Dependencies:** express, pg, redis, helmet, morgan, express-validator, winston, prom-client, dotenv

**TRANSACTION SERVICE**

- **Purpose:** Transaction processing, persist transactions, idempotency checks and 
- **Port:** 3002
- **ENV VAR:** DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD , REDIS_URL, NODE_ENV, LOG_LEVEL, WALLET_SERVICE_URL, RABBITMQ_URL
- **Dependencies:** axios, ****amqplib, dotenv, express, helmet, morgan, pg, prom-client, winston, redis, opposum, async-retry, uuid, express-validator

**NOTIFICATION SERVICE**

- **Purpose:** Listens for events (transactions) and sends emails/SMS to users.
- **Port:** 3003
- **ENV VAR:** RABBITMQ_URL, SMTP_HOST, SMTP_PORT, SMTP_USER, TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, LOG_LEVEL
- **Dependencies:** amqplib, dotenv, express, helmet, morgan, nodemailer, pg, prom-client, twilio, winston

**DATABASE**

- **Purpose:** Primary DB for users/wallets data
- **Port: 5432**
- **ENV VAR:** POSTGRES_USER, POSTGRES_PASSWORD
- **Dependencies:**