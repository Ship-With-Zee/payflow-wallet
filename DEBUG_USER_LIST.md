# Debugging "Failed to Fetch Name" Issue

## Problem
After creating a new user, older users don't show in the "Send Money" recipient dropdown, with error "failed to fetch name".

## Root Cause Analysis

**Flow:**
1. Frontend calls `/api/wallets` → API Gateway
2. API Gateway routes to `wallet-service:3001/wallets` → Wallet Service  
3. Wallet Service queries database: `SELECT * FROM wallets ORDER BY name`
4. Frontend expects: `{ user_id, name, balance }`
5. Frontend displays: `{u.name} ({u.user_id})`

**If `name` is missing → "failed to fetch name" error**

---

## Step-by-Step Debugging

### 1. Check Frontend Logs (Browser Console)

**Open browser DevTools (F12) → Console tab**

Look for:
- `Failed to load wallets: ...`
- Network errors (red in Network tab)
- Check Network tab → `/api/wallets` request

**Expected:** Status 200, response with array of wallets

**If 404/500:** API Gateway or Wallet Service issue

---

### 2. Check Wallet Service Logs

**In Kubernetes:**
```bash
# Get wallet service pods
kubectl get pods -n payflow -l app=wallet-service

# View logs
kubectl logs -n payflow -l app=wallet-service --tail=50

# Look for:
# - "Retrieved all wallets" (success)
# - "Failed to get wallets" (error)
# - "Cache hit for all wallets" (using cache)
```

**In Docker Compose:**
```bash
docker-compose logs wallet-service | tail -50
```

**What to look for:**
- Database connection errors
- Redis connection errors  
- Query errors
- Cache hit/miss patterns

---

### 3. Check API Gateway Logs

**In Kubernetes:**
```bash
kubectl logs -n payflow -l app=api-gateway --tail=50 | grep -i wallet
```

**In Docker Compose:**
```bash
docker-compose logs api-gateway | grep -i wallet
```

**What to look for:**
- Connection errors to wallet-service
- Timeout errors
- 502/503/504 errors

---

### 4. Test Wallet Service Directly

**In Kubernetes:**
```bash
# Port-forward wallet service
kubectl port-forward -n payflow svc/wallet-service 3001:3001

# Test endpoint (from another terminal)
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3001/wallets
```

**In Docker Compose:**
```bash
# Test directly
curl http://localhost:3001/wallets
```

**Expected Response:**
```json
[
  {
    "user_id": "user123",
    "name": "John Doe",
    "balance": "1000.00",
    "currency": "USD",
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-01T00:00:00.000Z"
  },
  {
    "user_id": "user456",
    "name": "Jane Smith",
    "balance": "500.00",
    ...
  }
]
```

**If `name` is missing:** Database issue (wallet created without name)

---

### 5. Check Database Directly

**In Kubernetes:**
```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow

# Query wallets table
SELECT user_id, name, balance FROM wallets ORDER BY name;
```

**In Docker Compose:**
```bash
docker-compose exec postgres psql -U payflow -d payflow -c "SELECT user_id, name, balance FROM wallets ORDER BY name;"
```

**What to check:**
- Does every wallet have a `name` field?
- Are there NULL names?
- Are there wallets without names?

**If NULL names found:**
```sql
-- Check for NULL names
SELECT user_id, name FROM wallets WHERE name IS NULL;

-- Fix NULL names (if needed)
UPDATE wallets SET name = 'Unknown User' WHERE name IS NULL;
```

---

### 6. Check Redis Cache

**In Kubernetes:**
```bash
# Connect to Redis
kubectl exec -it -n payflow $(kubectl get pod -n payflow -l app=redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli

# Check cache
GET wallets:all
```

**In Docker Compose:**
```bash
docker-compose exec redis redis-cli GET wallets:all
```

**If cache has stale data:**
```bash
# Clear cache
docker-compose exec redis redis-cli DEL wallets:all

# Or in Kubernetes:
kubectl exec -it -n payflow $(kubectl get pod -n payflow -l app=redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli DEL wallets:all
```

**Why this matters:**
- Cache is set for 30 seconds
- If cache has incomplete data (missing `name`), it's served for 30 seconds
- Clearing cache forces fresh database query

---

### 7. Check Network Policies (Kubernetes Only)

**If using network policies, check if wallet-service can receive traffic:**

```bash
# Check network policies
kubectl get networkpolicies -n payflow

# Check if API Gateway can reach wallet-service
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=api-gateway -o jsonpath='{.items[0].metadata.name}') -- \
  wget -qO- --timeout=3 http://wallet-service:3001/health
```

**If connection fails:** Network policy blocking traffic

---

## Most Common Issues & Fixes

### Issue 1: Wallet Created Without Name

**Symptom:** Database has wallets with `name = NULL`

**Fix:**
```sql
-- Check
SELECT user_id, name FROM wallets WHERE name IS NULL;

-- Fix (set name from user_id or email)
UPDATE wallets SET name = COALESCE(name, user_id) WHERE name IS NULL;
```

**Prevention:** Ensure auth-service creates wallet with name:
```javascript
// In auth-service, when creating wallet:
await axios.post(`${WALLET_SERVICE}/wallets`, {
  user_id: userId,
  name: name,  // ← Make sure this is included
  balance: 1000.00
});
```

---

### Issue 2: Stale Redis Cache

**Symptom:** Cache has old data without new users

**Fix:**
```bash
# Clear cache (see Step 6 above)
# Or restart wallet-service to clear cache
kubectl rollout restart deployment/wallet-service -n payflow
```

**Prevention:** Wallet service should invalidate cache when new wallet created (already implemented in code)

---

### Issue 3: Database Connection Failure

**Symptom:** Wallet service logs show "Failed to connect to database"

**Fix:**
```bash
# Check database is running
kubectl get pods -n payflow -l app=postgres

# Check wallet-service can connect
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=wallet-service -o jsonpath='{.items[0].metadata.name}') -- \
  nc -zv postgres 5432
```

---

### Issue 4: API Gateway Routing Failure

**Symptom:** API Gateway logs show "ECONNREFUSED" or "timeout"

**Fix:**
```bash
# Check wallet-service is running
kubectl get pods -n payflow -l app=wallet-service

# Check service exists
kubectl get svc -n payflow wallet-service

# Test from API Gateway pod
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=api-gateway -o jsonpath='{.items[0].metadata.name}') -- \
  wget -qO- --timeout=3 http://wallet-service:3001/health
```

---

## Quick Fix Commands

**If you just want to fix it quickly:**

```bash
# 1. Clear Redis cache
kubectl exec -it -n payflow $(kubectl get pod -n payflow -l app=redis -o jsonpath='{.items[0].metadata.name}') -- \
  redis-cli DEL wallets:all

# 2. Restart wallet-service (forces fresh cache)
kubectl rollout restart deployment/wallet-service -n payflow

# 3. Wait for restart
kubectl rollout status deployment/wallet-service -n payflow

# 4. Check database for NULL names
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c \
  "SELECT user_id, name FROM wallets WHERE name IS NULL;"

# 5. If NULL names found, fix them:
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c \
  "UPDATE wallets SET name = COALESCE(name, user_id) WHERE name IS NULL;"
```

---

## Container Responsibility Summary

**Primary Container:** `wallet-service`
- Queries database for wallets
- Returns wallet data (including `name` field)
- Caches results in Redis

**Secondary Containers:**
- `api-gateway` - Routes `/api/wallets` to wallet-service
- `frontend` - Displays the list (fails if `name` missing)
- `redis` - Caches wallet data (may have stale data)
- `postgres` - Stores wallet data (may have NULL names)

---

## Prevention

**Ensure wallet creation includes name:**
1. Check auth-service creates wallet with name
2. Check database schema has `name` as NOT NULL
3. Add validation in wallet-service to reject wallets without name

