# Multi-stage Dockerfile for production deployment

# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Create app user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Copy application files
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Create necessary directories
RUN mkdir -p logs && chown -R nodejs:nodejs logs

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]