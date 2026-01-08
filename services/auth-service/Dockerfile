# ============================================
# PayFlow Auth Service - Optimized Multi-Stage Build
# Target: <100MB (reduced from 184MB)
# ============================================

# #### Stage 1: Install Dependencies ####
# #### Why: Separate layer for dependencies - rarely changes ####
FROM alpine:3.21 AS deps

# Install Node.js and npm for dependencies
RUN apk add --no-cache nodejs npm

WORKDIR /app

# Copy package files for dependency installation
COPY package*.json ./

# Install ONLY production dependencies
# --ignore-scripts: Skip lifecycle scripts (faster install)
RUN npm install --only=production --ignore-scripts && \
    npm cache clean --force

# #### Stage 2: Production Image ####
# #### Why: Final image only contains what's needed ####
FROM alpine:3.21 AS production

RUN apk add --no-cache nodejs dumb-init

WORKDIR /app

# Create non-root user for security
# Why: Security best practice, minimal size impact (~1MB)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies from deps stage
# Why: Avoids re-downloading dependencies on code changes
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

# Expose port
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "const http = require('http'); const options = { host: 'localhost', port: process.env.PORT || 3004, path: '/health', timeout: 2000 }; const req = http.request(options, (res) => process.exit(res.statusCode === 200 ? 0 : 1)); req.on('error', () => process.exit(1)); req.end();"

# Use dumb-init
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["node", "server.js"]