FROM node:20-alpine

LABEL maintainer="Elite Full-Stack Engineer"
LABEL description="GPT Custom Actions Server with Bearer Auth + OpenAI Domain Verification"

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    openssl

# Create app directory
WORKDIR /app

# Copy package files
COPY app/package*.json ./

# Install production dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application files
COPY app/ ./

# Create directories
RUN mkdir -p public/.well-known logs

# Generate domain verification file (will be overridden by volume mount)
RUN echo '{"openai":{"domain_verification":"files.bytrix.my.id"}}' > public/.well-known/openai.json

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "index.js"]
