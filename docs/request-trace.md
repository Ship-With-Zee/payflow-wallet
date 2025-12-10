### **Full Request Trace-**

Tracing “send money” end to end required review of:

`services/api-gateway/server.js` (The Entry)

`services/transaction-service/server.js` 

`services/wallet-service/server.js`

`services/auth-service/server.js`

`services/notification-service/server.js`

`services/shared/`

`services/frontend`

### Step-by-Step Flow

### **Step 1:** Frontend Sends API Request

Request: POST /api/transactions/
User clicks "Send Money" in the React frontend(..\services\frontend\src\App.js). The frontend sends a POST request to the API Gateway containing the sender's wallet ID and amount. The JWT token from login is included in the Authorization header.
Token is stored in browser localStorage after login.

### **Step 2:** API Gateway Authenticates Request

Request: GET /verify (to Auth Service)
Before forwarding the transaction request, the gateway's auth middleware intercepts it and thus, 

Extracts the JWT from the Authorization header.

Delegates token verification to the Auth Service.

On success, attaches the authenticated user data to the request.

On failure, responds with 401 Unauthorized.

### Step 3: API Gateway Routes to Transaction Service

POST /transactions (Forwarded to Transaction Service) Once authenticated, the API Gateway routes the valid request to the Transaction Service. Also:

The gateway wraps the call in a circuit breaker (executeWithCircuitBreaker), ensuring that if the Transaction Service is failing or overloaded, the request fails fast rather than hanging the system.

Ownership Validation, the gateway logic often includes checks to ensure users can only access their own data, though for a new transaction, it primarily passes the payload (sender_id, receiver_id, amount) downstream via Axios.

Metrics Recording: The gateway logs the attempt (transactionMetrics.inc) to track success/failure rates for monitoring.

### Step 4: Transaction Service - Idempotency Check

Upon receiving the request, the Transaction Service uses the IdempotencyManager imported from (../services/shared/idempotency.js) to prevent duplicate processing of the same transfer.

The middleware queries Redis and checks Redis Cache using the idempotency-key from the request header (idempotency:${key}).

If the key exists, it logs "Idempotent request detected" and immediately returns the stored result (fromCache: true), stopping the flow here.

If not found, continues processing and caches result

### Step 5: Transaction Service Requests Transfer (Atomic Wallet Update)

Request: POST /wallets/transfer (Sent to Wallet Service) The Transaction Service calls the Wallet Service. Inside the Wallet Service (as seen in \services\wallet-service\server.js ):

 A database lock (FOR UPDATE) is applied to prevent race conditions.

Balance Validation: It confirms fromWallet.balance >= amount. If low, it returns 400 Insufficient funds.

It runs two SQL updates (Debit Sender, Credit Receiver) and commits them together.

Redis cache is cleared (redisClient.del) so the next "Get Balance" request fetches fresh data.

### Step 6: Transaction Service - Create Transaction Record

Database Update (UPDATE transactions SET status...)

Before calling the wallet, the service updates the transaction status to PROCESSING to indicate work is in progress.

Once the wallet transfer succeeds (via the Circuit Breaker/Retry logic), the service updates the status to COMPLETED and records the timestamp.

If the wallet call fails (after 2 retries), the catch block updates the status to FAILED with an error message.

### Step 7: Transaction Service - Publish Event to RabbitMQ Action

channel.sendToQueue('notifications', ...)

The code sends two separate messages to the notifications queue:

TRANSACTION_COMPLETED for the Sender, TRANSACTION_RECEIVED for the Receiver,

Messages are marked { persistent: true }, ensuring they survive if RabbitMQ restarts.

Then the queue is configured with a Dead Letter Exchange (dlx). If a notification fails to process (e.g., the Notification Service crashes), the message isn't lost; it's moved to a transactions.failed queue for later inspection.

### Step 8: Notification Service - Consume Event & Persist Event (Async)

Action: channel.consume

The Transaction Service's job is done once the message hits the queue. It does not wait for the email to be sent. The Notification Service will pick up these messages independently.

 The notification service picks up the message and immediately saves it to the notifications table. This ensures the user sees it in their "In-App Notification Center" even if the email fails later.

### Step 9: Notification Service - Fetch Contact Details

Action: Notification Service queries Auth/User DB (or calls Auth Service) to get email/phone for the User IDs.

### Step 10: Notification Service - Send Alerts

Action: Sends Email (SMTP) and SMS (Twilio).
Uses nodemailer to send transaction confirmation emails via SMTP server.
Uses environment variables: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
Email sending failures are logged but don't fail the transaction

Uses Twilio API with TWILIO_ACCOUNT_SID and auth token
Similar messages to email
SMS is optional (some users may not have phone numbers)

### Sequence Diagram
This diagram shows the complete end-to-end flow when a user sends money.


`````mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant G as API Gateway
    participant T as Transaction Svc
    participant W as Wallet Svc
    participant Q as RabbitMQ
    participant N as Notification Svc
    U->>G: POST /send (with Token)
    G->>T: Forward Request
    Note over T, W: Synchronous Transfer
    T->>W: POST /transfer
    W-->>T: 200 OK (Success)
    Note over T, Q: Asynchronous Handoff
    par Parallel Actions
        T->>Q: Publish "Transaction Complete"
        T-->>G: 200 OK
        G-->>U: "Success!"
    and Background Process
        Q->>N: Consume Message
        N->>N: Send Email/SMS
    end
