# PayFlow: A Production-Style Digital Wallet System

> **This repository is NOT a tutorial. It is a production-style system meant to be explored in layers.**

If you try to read everything at once, you will feel lost. That's expected — and avoidable.

---

## Before You Start (Read This First)

**This system is complex by design.** It uses microservices, message queues, and distributed patterns found in real production systems.

**The goal is not to understand everything immediately.** The goal is to learn how to approach complex systems without panicking.

### Read in This Order (Very Important)

#### Phase 0 — Orientation (Do this first)
**Goal:** Stop feeling lost. Build confidence.

1. **[docs/how-to-approach-this-system.md](docs/how-to-approach-this-system.md)** ← Start here
   - How seniors think about unfamiliar systems
   - What to look at first, what to ignore
   - Common beginner mistakes

**You are not expected to understand everything on the first pass. Re-reading is part of the learning.**

---

#### Phase 1 — Execution (Make it run)
**Goal:** Run the system without understanding everything.

2. **[docs/getting-started.md](docs/getting-started.md)**
   - Prerequisites
   - Running with Docker Compose
   - Basic verification

**Rules for this phase:**
- No architecture debates
- No Kubernetes yet
- No deep RabbitMQ theory
- Just: run it, click Send Money, see logs move

---

#### Phase 2 — Flow & Mental Models (Understand the system)
**Goal:** Know where things go. Understand one flow completely.

**Read after something breaks once.**

3. **[docs/tracing-a-single-request.md](docs/tracing-a-single-request.md)** ← Most important doc
   - Follow one "Send $100" request end-to-end
   - See every service involved
   - Understand where data lives

4. **[docs/system-flow.md](docs/system-flow.md)**
   - Complete transaction flow
   - How money moves
   - Duplicate prevention
   - Reversals

5. **[docs/architecture.md](docs/architecture.md)**
   - Service boundaries
   - Communication patterns
   - Why components exist

**Order matters:** Tracing doc first (concrete), then system-flow (full picture), then architecture (patterns).

---

#### Phase 3 — Debugging & Operations (Think like an engineer)
**Goal:** Know where to look when it breaks.

**Read only when stuck.**

6. **[docs/how-to-debug-this-system.md](docs/how-to-debug-this-system.md)**
   - Failure classification
   - Hypothesis-driven debugging
   - Real debugging example

7. **[docs/troubleshooting.md](docs/troubleshooting.md)**
   - Common issues and fixes
   - The NGINX/API URL problem (70% of issues)

8. **[docs/api-gateway-checks.md](docs/api-gateway-checks.md)**
   - What API Gateway actually checks
   - Reference, not onboarding

**These are explicitly labeled as reference docs — not for first-time reading.**

---

#### Phase 4 — Deployment & Scaling (After understanding)
**Goal:** Operate this in real environments.

**Read only after you understand the flow.**

9. **[docs/microk8s-deployment.md](docs/microk8s-deployment.md)**
   - Kubernetes deployment
   - Ingress configuration
   - Service mesh basics

10. **[docs/monitoring.md](docs/monitoring.md)**
    - Prometheus metrics
    - Loki logs
    - Grafana dashboards

11. **[docs/technology-choices.md](docs/technology-choices.md)**
    - Why RabbitMQ
    - Why Redis
    - Why PostgreSQL
    - Architecture decisions

**These are late-stage maturity docs. Don't read them until you understand the system.**

---

## The Story: Why This System Exists

Annie had just joined the PayFlow team as a junior DevOps engineer. Three days in, still learning the codebase, still getting familiar with the team's Slack channels.

Then a support ticket landed in the queue:

> "My transfer is taking too long. Please help me fix."

No red alerts flashing. No outage warnings. No panicked messages in #incidents.

Just a transaction stuck in processing.

Annie did what most newcomers would do first. She checked the logs, then the database.

The balance hadn't changed.

Her chest tightened. **Did we lose the payment?**

"Did something break?" she asked her senior lead.

He didn't rush to answer. Instead, he pulled up the architecture diagram and said something that would stick with her forever:

**"Let's follow the flow."**

---

## How PayFlow Actually Processes a Payment

When a user clicks **Send Money** in PayFlow, something counterintuitive happens: **the app doesn't move money immediately**.

Instead, the request goes through a carefully designed pipeline. Each layer has one job. No shortcuts.

### Layer 1: The API Gateway

The request first hits the **API Gateway**. The API moves fast and does only three things:

1. **Confirms the user is authenticated** - Valid session? Valid token?
2. **Validates the request** - Amount positive? Sufficient balance?
3. **Asks Redis one critical question**: *Have we seen this request ID before?*

That last check is how PayFlow prevents duplicate charges.

**If Redis says yes** - this request ID already exists - the API returns the cached result. Same request, same outcome. The payment doesn't enter the system twice.

**If Redis says no** - this is a new request - the API responds immediately:

> **"Transaction received. Processing."**

To the user, this feels instant. The UI updates. Confirmation appears.

**But here's the thing: the actual work hasn't started yet.**

### Layer 2: RabbitMQ (The Memory Layer)

Behind the scenes, the API doesn't process the payment. It does something smarter:

**It writes down what needs to happen.**

The transaction details are sent to **RabbitMQ** - a message queue that acts as the system's memory.

Annie saw the message sitting in the queue:

```
Transaction ID: 98234
Move $50.00 from User A to User B
```

Her senior explained it plainly:

> **"We write down what needs to happen before we try to do it. RabbitMQ doesn't move money. It doesn't touch balances. It just holds the instruction and refuses to forget it."**

This is the core principle: **separation of concerns**.

- **The API** handles user interaction (fast)
- **RabbitMQ** holds unfinished work (safely)
- **Workers** do the actual processing (reliably)

---

## What Happens When Things Go Wrong

Later that day, a worker picked up the message and began processing the transfer.

Then, during a period of heavy traffic, the worker restarted.

Nothing dramatic. No alarms. Just a normal container restart - the kind that happens dozens of times a day in distributed systems.

But here's what mattered:

**The worker never confirmed the transfer was complete.**

It never sent the **ACK signal** back to RabbitMQ.

When the worker came back online, RabbitMQ did exactly what it was designed to do:

**It handed the same message to the worker again.**

### Annie's Confusion

"Wait," Annie said, frowning at the screen. "Wouldn't that charge the user twice?"

Her senior smiled and shook his head.

**"Only if the worker skips a check."**

---

## The Safety Mechanism: Worker-Level Idempotency

Before touching any balance, the worker performs one quiet but critical operation.

**It asks the database:**

> *Have I already processed transaction ID 98234?*

**Two possible outcomes:**

### 1. If the record exists:
- The worker does nothing
- Sends ACK to RabbitMQ anyway
- Message gets deleted
- **No duplicate charge**

### 2. If the record doesn't exist:
- Worker proceeds with the transfer
- Debits sender, credits receiver
- Saves transaction record to database
- **Then - and only then - sends ACK**

In Annie's case, the record wasn't there yet. The first attempt had failed mid-flight.

So the worker completed the transfer safely, saved the transaction, and sent the confirmation signal.

Only then did RabbitMQ remove the message.

**Retries were expected. Duplicates were not.**

---

## The Real Reason for the Delay

The delay the user experienced wasn't a bug. It wasn't a failure.

**The system was waiting until it could finish safely.**

This is the architectural philosophy:

- ✅ Don't rush work
- ✅ Write it down first
- ✅ Hold it until you're certain
- ✅ Retry if needed
- ✅ Never lose a transaction
- ✅ Never charge twice

**Speed matters. But correctness matters more.**

---

## The Number That Tells the Truth

Later, Annie noticed a metric the team always kept on their monitoring dashboard:

**Messages waiting in RabbitMQ**

She asked about it. Her senior explained:

- **Low number (0–50)** → Everything's fine
- **Rising slowly (50–200)** → Workers are busy but keeping up
- **Rising fast (200+)** → Users will start feeling delays

The queue wasn't hiding problems. **It was making pressure visible.**

When messages pile up, the team knows immediately:
- Scale up workers
- Investigate slow processing
- Check external API performance
- Notify users proactively

**RabbitMQ turns invisible system stress into observable data.**

---

## The Complete Picture

By the end of the day, Annie finally understood the full architecture:

| Layer | Role | Why It Matters |
|-------|------|----------------|
| **API Gateway** | Fast acknowledgment | Users get immediate feedback |
| **Redis** | Idempotency at entry | Same request twice? Caught immediately |
| **RabbitMQ** | Durable task queue | Never forgets unfinished work |
| **Worker** | Actual processing | Checks for duplicates before acting |
| **Database** | Source of truth | Confirms what actually happened |

Each layer does one job. No shortcuts. No guessing.

---

## Closing the Ticket

Annie replied to the support ticket with confidence:

> "Your transfer is processing and will complete shortly. Your funds are safe."

Five minutes later, the customer responded:

> "Got it. Thanks."

She closed the ticket.

**Not because the system was fast.**

**But because it was careful by design.**

---

## The Lesson That Stuck

That night, Annie wrote a note to herself:

> **Reliable systems assume restarts will happen. They don't rush work. They remember it.**

And now, she finally understood why PayFlow was built this way.

**Speed gets you users. Safety keeps them.**

---

## Annie's Questions (And The Answers That Made Everything Click)

After understanding the flow, Annie had more questions. Questions that would help her debug issues, explain the system to others, and truly understand why things were built this way.

### Q1: Why does the API Gateway exist? What if the frontend talked directly to every microservice?

Annie asked: "Why can't the frontend just call each service directly? Why do we need a middleman?"

**The Problem Without API Gateway:**

Imagine the frontend needs to:
- Login → Call `http://auth-service:3004/auth/login`
- Check balance → Call `http://wallet-service:3001/wallets/user-123`
- Send money → Call `http://transaction-service:3002/transactions`
- Get notifications → Call `http://notification-service:3003/notifications`

**What breaks:**
1. **Frontend needs to know all service URLs** - If a service moves, frontend breaks
2. **Each service handles auth separately** - Inconsistent, error-prone
3. **No central place to add features** - Want logging? Add it to 4 services
4. **Rate limiting is scattered** - Each service does it differently

**With API Gateway:**
- Frontend only knows: `http://api-gateway:3000/api/*`
- API Gateway handles auth once, routes to correct service
- Add logging/monitoring in one place
- Consistent rate limiting

**Real-world analogy:** Instead of calling 4 different phone numbers, you call one receptionist who routes your call.

---

### Q2: In Send Money, why does Transaction Service call Wallet Service twice (debit sender THEN credit receiver)? Why not combine them?

Annie asked: "I see the code calls Wallet Service once, but it does two things. Why not just one call?"

**The Answer:** It IS one call! But inside that call, Wallet Service does two database operations.

**What Actually Happens:**

```javascript
// Transaction Service calls Wallet Service ONCE
POST /wallets/transfer
Body: { fromUserId: "user-1", toUserId: "user-2", amount: 100 }

// Inside Wallet Service, it does TWO database operations:
BEGIN;
  UPDATE wallets SET balance = balance - 100 WHERE user_id = 'user-1';  // Debit
  UPDATE wallets SET balance = balance + 100 WHERE user_id = 'user-2';  // Credit
COMMIT;
```

**Why Two Operations?**
- **Database transactions require both** - Can't do "transfer" in one SQL command
- **Atomicity** - Either both happen, or neither (if one fails, both rollback)
- **Row locking** - Each wallet needs to be locked separately to prevent race conditions

**Why Not One SQL Command?**
SQL doesn't have a "transfer" command. You must:
1. Subtract from sender
2. Add to receiver
3. Wrap both in a transaction (BEGIN/COMMIT)

**Follow-up: Why Could Duplicates Happen?**

Annie asked: "If it's one call, how could we charge twice?"

**Scenario 1: User Double-Clicks**
```
Click 1 → API Gateway → Transaction Service → Creates TXN-123
Click 2 → API Gateway → Transaction Service → Creates TXN-124
Result: Two transactions (user charged twice)
```

**Solution:** Redis idempotency check at API Gateway catches this.

**Scenario 2: Worker Crashes, RabbitMQ Retries**
```
Worker processes TXN-123 → Calls Wallet Service → Crashes mid-transfer
RabbitMQ retries → Worker processes TXN-123 again → Calls Wallet Service again
Result: Money transferred twice
```

**Solution:** Database transaction ensures atomicity. If first transfer succeeded, second one sees balance already changed and fails validation.

---

### Q3: If RabbitMQ goes down, what happens? What continues working and what becomes delayed?

Annie asked: "If RabbitMQ crashes, does everything break?"

**What Still Works (Synchronous Operations):**
- ✅ **Login/Register** - Direct HTTP calls, no RabbitMQ
- ✅ **Check Balance** - Direct HTTP calls, no RabbitMQ
- ✅ **View Transactions** - Direct HTTP calls, no RabbitMQ
- ✅ **Create Transaction** - Transaction Service creates record, but can't queue message

**What Breaks (Asynchronous Operations):**
- ❌ **Transaction Processing** - Messages can't be queued, transactions stay PENDING
- ❌ **Notifications** - Can't send emails (no messages in queue)
- ❌ **Background Jobs** - Any async work stops

**What Happens:**
1. User clicks "Send $100" → Transaction Service creates record (status: PENDING)
2. Transaction Service tries to publish to RabbitMQ → **Fails** (RabbitMQ is down)
3. Transaction stays PENDING in database
4. After 1 minute → CronJob reverses it (status: FAILED)
5. User's money unblocked, can try again

**Real-world analogy:** Like a post office being closed. You can still make phone calls (synchronous), but letters (messages) pile up until the post office reopens.

---

### Q4: How does Redis prevent a double transaction from happening?

Annie asked: "I understand Redis is fast, but how does it actually prevent duplicates?"

**The Mechanism:**

```javascript
// User clicks "Send $100" with idempotency-key: "abc-123"

// Step 1: API Gateway checks Redis
const cached = await redis.get('idempotency:abc-123');

if (cached) {
  // Already processed - return cached result
  return res.json(JSON.parse(cached));  // Same transaction ID, no new charge
}

// Step 2: Process request
const result = await createTransaction(...);

// Step 3: Cache result
await redis.setEx('idempotency:abc-123', 86400, JSON.stringify(result));
// TTL: 24 hours (same request within 24 hours = same result)
```

**What Happens on Double-Click:**

**First Click:**
1. Redis: "abc-123" doesn't exist → Process request
2. Create transaction TXN-123
3. Cache result: `{ id: "TXN-123", status: "PENDING" }`

**Second Click (same idempotency-key):**
1. Redis: "abc-123" exists → Return cached result
2. **No new transaction created** → User not charged twice

**Why It Works:**
- **Same idempotency-key = Same request** - Frontend generates unique key per user action
- **Redis is fast** - Microseconds vs milliseconds for database
- **24-hour TTL** - Prevents duplicates even if user refreshes page

**Real-world analogy:** Like a bouncer at a club with a guest list. If your name is already checked, you don't get in again (even if you try to enter twice).

---

### Q5: Can Transaction Service complete a money transfer without calling Auth Service or Wallet Service? Why or why not?

Annie asked: "Could Transaction Service just move money itself? Why does it need Wallet Service?"

**Short Answer:** No. Transaction Service cannot move money without Wallet Service.

**Why Transaction Service Needs Wallet Service:**

**Transaction Service's Job:**
- Create transaction record
- Queue work for processing
- Track transaction status

**Wallet Service's Job:**
- Actually move money (update balances)
- Ensure atomicity (database transactions)
- Validate sufficient funds

**What Happens If Transaction Service Tried To Move Money Directly:**

```javascript
// Transaction Service tries to update balances directly
await db.query('UPDATE wallets SET balance = balance - 100 WHERE user_id = $1', [fromUserId]);
await db.query('UPDATE wallets SET balance = balance + 100 WHERE user_id = $2', [toUserId]);
```

**Problems:**
1. **No atomicity** - If second query fails, first one already happened (money lost!)
2. **No validation** - Doesn't check sufficient funds
3. **No row locking** - Race conditions possible
4. **Code duplication** - Transfer logic in two places

**Why Wallet Service Exists:**
- **Single Responsibility** - Wallet Service owns all balance operations
- **Database Transactions** - Ensures atomicity (BEGIN/COMMIT)
- **Row Locking** - Prevents race conditions
- **Validation** - Checks sufficient funds before transferring

**Real-world analogy:** Like a bank. The teller (Transaction Service) creates the transaction record, but only the vault (Wallet Service) can actually move money. The teller can't access the vault directly.

**What About Auth Service?**

Transaction Service doesn't need to call Auth Service for transfers. Auth Service is only needed when:
- User logs in (creates JWT token)
- API Gateway verifies token (before request reaches Transaction Service)

By the time a request reaches Transaction Service, authentication is already done by API Gateway.

---

## Quick Start

### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- (Optional) MicroK8s for Kubernetes deployment

### Run Locally

```bash
# Start all services
docker-compose up -d

# Access application
# Frontend: http://localhost:3000
# API Gateway: http://localhost:3000/api
```

### Deploy to Kubernetes

See [Kubernetes Deployment Guide](docs/microk8s-deployment.md)

---

## Key Takeaways

If you're building backend systems, payment platforms, or anything handling critical user data, remember:

✅ **Accept requests fast** (API responds in milliseconds)  
✅ **Write work down** (queues prevent data loss)  
✅ **Process asynchronously** (workers can restart safely)  
✅ **Check for duplicates** (at API level AND worker level)  
✅ **Require confirmation** (ACK before deletion)  
✅ **Make pressure visible** (monitor queue depth)  

This pattern isn't just for fintech. It applies to:
- E-commerce order processing
- Email delivery systems
- Notification pipelines
- Any workflow where losing work is unacceptable

---

## About This Story

PayFlow is a real fintech application demonstrating production patterns. This architecture is used by Stripe, Square, PayPal, and countless other companies processing billions in payments daily.

**Found this helpful?** Share it with someone building backend or fintech systems.

---

*Speed gets you users. Safety keeps them.*
