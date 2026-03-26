# ─────────────────────────────────────────
# Stage 1: Install dependencies
# ─────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# ─────────────────────────────────────────
# Stage 2: Build the application
# ─────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ─────────────────────────────────────────
# Stage 3: Lean production image
# ─────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

# Non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nodeuser

COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodeuser:nodejs /app/build ./build
COPY --from=builder --chown=nodeuser:nodejs /app/package.json ./

USER nodeuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
