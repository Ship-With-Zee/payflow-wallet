# ============================================
# PayFlow Notification Service - Optimized Multi-Stage Build
# Target: <110MB (reduced from 221MB)
# ============================================

FROM alpine:3.21 AS deps

RUN apk add --no-cache nodejs npm

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production --ignore-scripts && \
    npm cache clean --force

FROM alpine:3.21 AS production

RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache nodejs dumb-init libc6-compat

WORKDIR /app

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

COPY --chown=nodejs:nodejs . .

USER nodejs

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "const http = require('http'); const options = { host: 'localhost', port: process.env.PORT || 3003, path: '/health', timeout: 2000 }; const req = http.request(options, (res) => process.exit(res.statusCode === 200 ? 0 : 1)); req.on('error', () => process.exit(1)); req.end();"

# Entrypoint
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["node", "server.js"]
