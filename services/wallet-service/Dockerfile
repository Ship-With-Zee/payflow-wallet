# ============================================
# PayFlow Wallet Service - Optimized Multi-Stage Build
# Target: <100MB (reduced from 192MB)
# ============================================

FROM alpine:3.21 AS deps

RUN apk add --no-cache nodejs npm

WORKDIR /app

COPY package*.json ./

RUN npm install --only=production --ignore-scripts && \
    npm cache clean --force

FROM alpine:3.21 AS production

RUN apk add --no-cache nodejs dumb-init

WORKDIR /app

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

COPY --chown=nodejs:nodejs . .

USER nodejs

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "const http = require('http'); const options = { host: 'localhost', port: process.env.PORT || 3001, path: '/health', timeout: 2000 }; const req = http.request(options, (res) => process.exit(res.statusCode === 200 ? 0 : 1)); req.on('error', () => process.exit(1)); req.end();"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["node", "server.js"]