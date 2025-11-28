#!/bin/bash

# ==========================================
# Backup GPT Custom Actions Server
# ==========================================

set -e

BACKUP_DIR="/root/gpt-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="gpt-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   GPT Custom Actions - Backup                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Create backup directory
mkdir -p "${BACKUP_PATH}"

echo "📦 Creating backup: ${BACKUP_NAME}"
echo ""

# Backup .env file (contains Bearer Token!)
if [ -f "/opt/gpt/app/.env" ]; then
    echo "✓ Backing up .env (with Bearer Token)..."
    cp /opt/gpt/app/.env "${BACKUP_PATH}/"
fi

# Backup public directory (domain verification)
if [ -d "/opt/gpt/app/public" ]; then
    echo "✓ Backing up public directory..."
    cp -r /opt/gpt/app/public "${BACKUP_PATH}/"
fi

# Backup nginx config
if [ -f "/etc/nginx/sites-available/gpt-actions" ]; then
    echo "✓ Backing up nginx config..."
    cp /etc/nginx/sites-available/gpt-actions "${BACKUP_PATH}/"
fi

# Backup SSL certificates (if custom)
if [ -d "/opt/gpt/ssl" ]; then
    echo "✓ Backing up SSL certificates..."
    cp -r /opt/gpt/ssl "${BACKUP_PATH}/"
fi

# Backup PM2 ecosystem config
if [ -f "/opt/gpt/app/ecosystem.config.js" ]; then
    echo "✓ Backing up PM2 config..."
    cp /opt/gpt/app/ecosystem.config.js "${BACKUP_PATH}/"
fi

# Create backup info file
cat > "${BACKUP_PATH}/backup-info.txt" <<EOF
GPT Custom Actions Server - Backup
===================================

Backup Date: $(date)
Backup Name: ${BACKUP_NAME}

Contents:
- .env (includes Bearer Token)
- public directory (.well-known/openai.json, actions.json)
- nginx configuration
- SSL certificates (if custom)
- PM2 ecosystem config

Restore Instructions:
1. Copy .env to /opt/gpt/app/.env
2. Copy public directory to /opt/gpt/app/public
3. Copy nginx config to /etc/nginx/sites-available/gpt-actions
4. Copy SSL certs to /opt/gpt/ssl (if applicable)
5. Restart services: pm2 restart all && systemctl restart nginx

Important:
- Bearer Token is in .env file (SERVER_BEARER_TOKEN)
- Keep this backup secure!
EOF

# Create compressed archive
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

echo ""
echo "✅ Backup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To restore:"
echo "  cd ${BACKUP_DIR}"
echo "  tar -xzf ${BACKUP_NAME}.tar.gz"
echo "  cd ${BACKUP_NAME}"
echo "  cat backup-info.txt"
echo ""
