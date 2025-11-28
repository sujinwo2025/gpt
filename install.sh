#!/bin/bash

# ==========================================
# GPT Custom Actions - Installation Script
# Quick install helper (alternative to menu)
# ==========================================

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   GPT Custom Actions - Quick Install                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Ask for installation mode
echo "Select installation mode:"
echo "1) Native (PM2 + Nginx)"
echo "2) Docker (Docker-Compose)"
read -p "Choice [1-2]: " MODE

if [ "$MODE" = "1" ]; then
  echo "Installing in Native mode..."
  
  # Update system
  apt update && apt upgrade -y
  
  # Install dependencies
  apt install -y curl git nginx certbot python3-certbot-nginx
  
  # Install Node.js 20
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt install -y nodejs
  
  # Install PM2
  npm install -g pm2
  
  # Create directories
  mkdir -p /opt/gpt/app/public/.well-known
  mkdir -p /opt/gpt/app/logs
  
  # Install app dependencies
  cd /opt/gpt/app
  npm install
  
  # Generate Bearer Token
  BEARER_TOKEN=$(openssl rand -base64 48 | tr -d '/+=' | head -c 64)
  
  # Create .env
  cat > /opt/gpt/app/.env <<EOF
PORT=3000
NODE_ENV=production
SERVER_BEARER_TOKEN=${BEARER_TOKEN}
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
S3_REGION=us-east-1
S3_BUCKET=your-bucket
DOMAIN=files.bytrix.my.id
EOF

  # Generate OpenAPI
  node generate-actions.js full
  
  # Setup Nginx
  cp /opt/gpt/nginx.conf /etc/nginx/sites-available/gpt-actions
  ln -sf /etc/nginx/sites-available/gpt-actions /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl restart nginx
  
  # Start with PM2
  pm2 start ecosystem.config.js
  pm2 save
  pm2 startup | tail -n 1 | bash
  
  echo ""
  echo "✅ INSTALLATION COMPLETE!"
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "Bearer Token (SAVE THIS):"
  echo "${BEARER_TOKEN}"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "Next steps:"
  echo "1. Update .env with your Supabase and S3 credentials"
  echo "2. Setup SSL: sudo certbot --nginx -d files.bytrix.my.id"
  echo "3. Verify domain: https://files.bytrix.my.id/.well-known/openai.json"
  echo "4. Import to Custom GPT: https://files.bytrix.my.id/actions.json"
  echo ""
  
elif [ "$MODE" = "2" ]; then
  echo "Installing in Docker mode..."
  
  # Install Docker
  apt update
  apt install -y docker.io docker-compose
  systemctl enable docker
  systemctl start docker
  
  # Create directories
  mkdir -p /opt/gpt/app/public/.well-known
  mkdir -p /opt/gpt/app/logs
  
  # Generate Bearer Token
  BEARER_TOKEN=$(openssl rand -base64 48 | tr -d '/+=' | head -c 64)
  
  # Create .env
  cat > /opt/gpt/app/.env <<EOF
PORT=3000
NODE_ENV=production
SERVER_BEARER_TOKEN=${BEARER_TOKEN}
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
S3_REGION=us-east-1
S3_BUCKET=your-bucket
DOMAIN=files.bytrix.my.id
EOF

  # Start Docker
  cd /opt/gpt
  docker-compose up -d --build
  
  echo ""
  echo "✅ DOCKER INSTALLATION COMPLETE!"
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "Bearer Token (SAVE THIS):"
  echo "${BEARER_TOKEN}"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "Container status:"
  docker-compose ps
  echo ""
  
else
  echo "Invalid choice"
  exit 1
fi

echo "Use ./menu.sh for full management interface"
