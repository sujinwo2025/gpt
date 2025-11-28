#!/bin/bash

# ========================================
# GPT Custom Actions Server - FINAL VERSION
# Bearer Token + Domain Verification + S3 + Supabase
# ========================================

set -e

PROJECT_ROOT="/opt/gpt"
APP_DIR="${PROJECT_ROOT}/app"
ENV_FILE="${APP_DIR}/.env"
NGINX_CONF="/etc/nginx/sites-available/gpt-actions"
DOMAIN="files.bytrix.my.id"
WELL_KNOWN_FILE="${APP_DIR}/public/.well-known/openai.json"

# Ensure directory structure automatically (migration helper)
ensure_structure() {
    # If running outside /opt/gpt (e.g., cloned to $PWD), migrate automatically
    CURRENT_DIR=$(pwd)
    if [ "${CURRENT_DIR}" != "${PROJECT_ROOT}" ] && [ -d "${CURRENT_DIR}" ]; then
        # Detect if this script resides in a different folder than /opt/gpt
        if [ ! -d "${PROJECT_ROOT}" ]; then
            echo "[AUTO] Creating ${PROJECT_ROOT} and migrating current repo..."
            mkdir -p "${PROJECT_ROOT}" || true
            # Copy all contents except node_modules/temp artifacts
            rsync -a --exclude 'node_modules' --exclude '.git' --exclude 'logs' ./ "${PROJECT_ROOT}/" 2>/dev/null || cp -r ./* "${PROJECT_ROOT}/" || true
        fi
    fi

    # Create app directory if missing
    if [ ! -d "${APP_DIR}" ]; then
        echo "[AUTO] Creating app directory: ${APP_DIR}"
        mkdir -p "${APP_DIR}"
    fi

    # Move misplaced files into app/ if they exist at root
    for f in index.js generate-actions.js ecosystem.config.js; do
        if [ -f "${PROJECT_ROOT}/$f" ] && [ ! -f "${APP_DIR}/$f" ]; then
            echo "[AUTO] Moving $f into app/"
            mv "${PROJECT_ROOT}/$f" "${APP_DIR}/$f"
        fi
    done

    # Move package.json if at root not in app
    if [ -f "${PROJECT_ROOT}/package.json" ] && [ ! -f "${APP_DIR}/package.json" ]; then
        echo "[AUTO] Moving package.json into app/"
        mv "${PROJECT_ROOT}/package.json" "${APP_DIR}/package.json"
    fi

    # Ensure public/.well-known exists
    if [ ! -d "${APP_DIR}/public/.well-known" ]; then
        echo "[AUTO] Creating public/.well-known"
        mkdir -p "${APP_DIR}/public/.well-known"
    fi

    # Ensure actions.json generated if missing and we have generator
    if [ -f "${APP_DIR}/generate-actions.js" ] && [ ! -f "${APP_DIR}/public/actions.json" ]; then
        echo "[AUTO] Generating initial OpenAPI spec (full)"
        (cd "${APP_DIR}" && node generate-actions.js full || true)
    fi

    # Ensure domain verification file
    if [ ! -f "${WELL_KNOWN_FILE}" ]; then
        echo "[AUTO] Creating domain verification file"
        cat > "${WELL_KNOWN_FILE}" <<EOF
{
  "openai": {
    "domain_verification": "${DOMAIN}"
  }
}
EOF
    fi

    # Inform user about structure
    echo "[AUTO] Structure ensured. PROJECT_ROOT=${PROJECT_ROOT} APP_DIR=${APP_DIR}"
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

banner() {
    echo -e "${GREEN}"
    echo " /\$\$\$\$\$\$\$  /\$\$\$\$\$\$\$\$ /\$\$\$\$\$\$\$\$       /\$\$\$\$\$\$  /\$\$\$\$\$\$\$\$ /\$\$ /\$\$ /\$\$\$\$\$\$\$\$"
    echo "/\$\$__  \$\$|__  \$\$__/|__  \$\$__/      /\$\$__  \$\$|__  \$\$__/|__/|  \$\$__  \$\$"
    echo "| \$\$  \\\__/   | \$\$      | \$\$        | \$\$  \\ \$\$   | \$\$    /\$\$| \$\$ \\ \$\$"
    echo "| \$\$ /\$\$\$\$  | \$\$\$\$\$\$\$\$/  | \$\$        | \$\$  | \$\$   | \$\$\$\$\$\$\$\$/| \$\$| \$\$ | \$\$"
    echo "| \$\$|_  \$\$ | \$\$____/   | \$\$        | \$\$  | \$\$   | \$\$____/ | \$\$| \$\$ | \$\$"
    echo "| \$\$  \\ \$\$ | \$\$        | \$\$        | \$\$  | \$\$   | \$\$      | \$\$| \$\$ | \$\$"
    echo "|  \$\$\$\$\$\$/ | \$\$\$\$\$\$\$\$ | \$\$        |  \$\$\$\$\$\$/   | \$\$      | \$\$|  \$\$\$\$\$\$\$/"
    echo " \\______/  |________/|__/         \\______/    |__/      |__/ \\______/"
    echo -e "${CYAN}"
    echo "════════════════════════════════════════════════════════════════════════"
    echo -e "${YELLOW}  Custom Actions Server – files.bytrix.my.id${NC}"
    echo -e "${MAGENTA}  Bearer Token + Domain Verification + Supabase + S3${NC}"
    echo -e "${BLUE}  Path: /opt/gpt${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_menu() {
    banner
    echo -e "${CYAN}[ INSTALLATION ]${NC}"
    echo "1)  Install pertama kali (Native — PM2 + Nginx)"
    echo "2)  Install pertama kali (Docker-Compose mode)"
    echo "3)  Update dari GitHub + rebuild + restart"
    echo "4)  Restart semua service"
    echo "5)  Lihat log real-time"
    echo ""
    echo -e "${YELLOW}[ SECURITY & OPENAI VERIFICATION ]${NC}"
    echo "6)  Generate ulang Bearer Token (64 char) → otomatis update OpenAPI"
    echo "7)  Cek status domain verification OpenAI"
    echo "8)  Ganti Bearer Token manual (paste sendiri)"
    echo ""
    echo -e "${GREEN}[ SSL MANAGEMENT ]${NC}"
    echo "9)  Aktifkan SSL Let's Encrypt"
    echo "10) Aktifkan Custom SSL → Paste fullchain.pem + privkey.pem"
    echo "11) Ganti Custom SSL"
    echo "12) Kembali ke Let's Encrypt"
    echo ""
    echo -e "${BLUE}[ S3 EKSTERNAL ]${NC}"
    echo "13) Change S3 Endpoint"
    echo "14) Change S3 Access Key ID"
    echo "15) Change S3 Secret Access Key"
    echo "16) Change S3 Region"
    echo "17) Change Default Bucket"
    echo "18) Test koneksi S3"
    echo ""
    echo -e "${MAGENTA}[ SUPABASE ]${NC}"
    echo "19) Ganti Supabase Service Role Key"
    echo ""
    echo -e "${CYAN}[ GENERATE OPENAPI 3.1.0 — DENGAN BEARER ]${NC}"
    echo "20) Generate → Hanya Supabase CRUD"
    echo "21) Generate → Hanya S3 File Operations"
    echo "22) Generate → Full Combo (default)"
    echo ""
    echo -e "${YELLOW}[ DOCKER CONTROL ]${NC}"
    echo "23) Start Docker-Compose"
    echo "24) Stop Docker-Compose"
    echo "25) Rebuild Docker tanpa cache"
    echo ""
    echo -e "${RED}[ MAINTENANCE ]${NC}"
    echo "26) Test semua endpoint (dengan Bearer Token)"
    echo "27) Backup semua (termasuk Bearer Token)"
    echo "28) Uninstall total bersih"
    echo ""
    echo "0)  Keluar"
    echo ""
    echo -n "Pilih [0-28]: "
}

generate_bearer_token() {
    openssl rand -base64 48 | tr -d '/+=' | head -c 64
}

install_native() {
    echo -e "${GREEN}[INSTALL NATIVE MODE]${NC}"
    ensure_structure
    
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
    mkdir -p ${PROJECT_ROOT}
    cd ${PROJECT_ROOT}
    
    # Clone or copy files
    if [ -d ".git" ]; then
        git pull
    fi
    
    mkdir -p ${APP_DIR}/public/.well-known
    mkdir -p ${APP_DIR}/logs
    
    # Generate Bearer Token
    BEARER_TOKEN=$(generate_bearer_token)
    
    # Create .env
    cat > ${ENV_FILE} <<EOF
# Server
PORT=3000
NODE_ENV=production

# Bearer Token Authentication
SERVER_BEARER_TOKEN=${BEARER_TOKEN}

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# S3 Compatible Storage
S3_ENDPOINT=https://s3.amazonaws.com
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
S3_REGION=us-east-1
S3_BUCKET=your-bucket

# Domain
DOMAIN=${DOMAIN}
EOF

    # Create domain verification file
    cat > ${WELL_KNOWN_FILE} <<EOF
{
  "openai": {
    "domain_verification": "${DOMAIN}"
  }
}
EOF

    # Install npm packages
    cd ${APP_DIR}
    npm install
    
    # Generate OpenAPI
    node generate-actions.js full
    
    # Setup Nginx
    cat > ${NGINX_CONF} <<'NGINXCONF'
server {
    listen 80;
    server_name files.bytrix.my.id;
    
    root /opt/gpt/app/public;
    
    # Static files (including .well-known)
    location / {
        try_files $uri $uri/ =404;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # OpenAPI JSON
    location /actions.json {
        proxy_pass http://localhost:3000/actions.json;
        proxy_set_header Host $host;
    }
}
NGINXCONF

    ln -sf ${NGINX_CONF} /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx
    
    # Start with PM2
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup | tail -n 1 | bash
    
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo -e "${YELLOW}Bearer Token:${NC} ${BEARER_TOKEN}"
    echo -e "${CYAN}Domain Verification:${NC} https://${DOMAIN}/.well-known/openai.json"
    echo -e "${CYAN}OpenAPI Spec:${NC} https://${DOMAIN}/actions.json"
    echo ""
    echo -e "${RED}SAVE THIS BEARER TOKEN!${NC}"
}

install_docker() {
    echo -e "${GREEN}[INSTALL DOCKER MODE]${NC}"
    ensure_structure
    
    # Install Docker
    apt update
    apt install -y docker.io docker-compose
    systemctl enable docker
    systemctl start docker
    
    # Create directories
    mkdir -p ${PROJECT_ROOT}
    cd ${PROJECT_ROOT}
    
    mkdir -p ${APP_DIR}/public/.well-known
    mkdir -p ${APP_DIR}/logs
    
    # Generate Bearer Token
    BEARER_TOKEN=$(generate_bearer_token)
    
    # Create .env
    cat > ${ENV_FILE} <<EOF
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
DOMAIN=${DOMAIN}
EOF

    # Create domain verification
    cat > ${WELL_KNOWN_FILE} <<EOF
{
  "openai": {
    "domain_verification": "${DOMAIN}"
  }
}
EOF

    # Start Docker
    cd ${PROJECT_ROOT}
    docker-compose up -d --build
    
    echo -e "${GREEN}✓ Docker installation complete!${NC}"
    echo -e "${YELLOW}Bearer Token:${NC} ${BEARER_TOKEN}"
    echo -e "${CYAN}Domain Verification:${NC} https://${DOMAIN}/.well-known/openai.json"
}

update_from_github() {
    echo -e "${YELLOW}[UPDATE FROM GITHUB]${NC}"
    ensure_structure
    cd ${PROJECT_ROOT}
    if [ -d ".git" ]; then
        echo "Git repo detected. Fetching and resetting to origin/main..."
        git remote set-url origin https://github.com/sujinwo2025/gpt.git 2>/dev/null || true
        git fetch --all || true
        if git rev-parse --verify origin/main >/dev/null 2>&1; then
            git reset --hard origin/main
        elif git rev-parse --verify origin/master >/dev/null 2>&1; then
            git reset --hard origin/master
        else
            echo -e "${RED}Remote main/master not found. Attempting pull.${NC}"
            git pull || true
        fi
    else
        echo "No .git directory found. Initializing repository in-place..."
        # If directory not empty, we can't clone directly. Initialize then attach remote.
        if [ "$(ls -A ${PROJECT_ROOT} 2>/dev/null | wc -l)" -gt 0 ]; then
            echo "Directory is non-empty. Converting existing folder into a git repo."
            git init
            git remote add origin https://github.com/sujinwo2025/gpt.git 2>/dev/null || true
            git fetch --depth=1 origin main || git fetch --depth=1 origin master || true
            if git rev-parse --verify origin/main >/dev/null 2>&1; then
                git reset --mixed origin/main
            elif git rev-parse --verify origin/master >/dev/null 2>&1; then
                git reset --mixed origin/master
            else
                echo -e "${RED}Remote branches not accessible. Performing safety add/commit initial state.${NC}"
                git add .
                git commit -m "chore: initialize local repo before sync" || true
            fi
        else
            echo "Directory empty; performing fresh clone..."
            cd /opt
            rm -rf gpt
            git clone https://github.com/sujinwo2025/gpt.git gpt
            cd gpt
        fi
    fi
    cd ${APP_DIR}
    npm install

    # Ensure scripts are executable
    if [ -f "${PROJECT_ROOT}/menu.sh" ]; then
        chmod +x "${PROJECT_ROOT}/menu.sh" || true
    fi
    if [ -f "${PROJECT_ROOT}/install.sh" ]; then
        chmod +x "${PROJECT_ROOT}/install.sh" || true
    fi
    echo "[AUTO] chmod +x applied to menu.sh and install.sh"
    
    if [ -f "${PROJECT_ROOT}/docker-compose.yml" ]; then
        docker-compose down
        docker-compose up -d --build
    else
        pm2 restart all
    fi
    
    echo -e "${GREEN}✓ Update complete!${NC}"
}

restart_services() {
    echo -e "${YELLOW}[RESTART SERVICES]${NC}"
    
    if docker ps > /dev/null 2>&1 && docker ps | grep -q gpt; then
        docker-compose -f ${PROJECT_ROOT}/docker-compose.yml restart
    else
        pm2 restart all
    fi
    
    systemctl restart nginx 2>/dev/null || true
    echo -e "${GREEN}✓ Services restarted!${NC}"
}

show_logs() {
    echo -e "${CYAN}[LOGS REAL-TIME]${NC}"
    
    if docker ps > /dev/null 2>&1 && docker ps | grep -q gpt; then
        docker-compose -f ${PROJECT_ROOT}/docker-compose.yml logs -f
    else
        pm2 logs
    fi
}

regenerate_bearer_token() {
    echo -e "${YELLOW}[REGENERATE BEARER TOKEN]${NC}"
    
    NEW_TOKEN=$(generate_bearer_token)
    
    # Update .env
    if [ -f "${ENV_FILE}" ]; then
        sed -i "s/^SERVER_BEARER_TOKEN=.*/SERVER_BEARER_TOKEN=${NEW_TOKEN}/" ${ENV_FILE}
    else
        echo "SERVER_BEARER_TOKEN=${NEW_TOKEN}" >> ${ENV_FILE}
    fi
    
    # Regenerate OpenAPI
    cd ${APP_DIR}
    node generate-actions.js full
    
    # Restart
    restart_services
    
    echo -e "${GREEN}✓ New Bearer Token generated!${NC}"
    echo -e "${YELLOW}Bearer Token:${NC} ${NEW_TOKEN}"
    echo -e "${RED}Update your Custom GPT with this new token!${NC}"
}

check_domain_verification() {
    echo -e "${CYAN}[CHECK DOMAIN VERIFICATION]${NC}"
    echo ""
    
    if [ -f "${WELL_KNOWN_FILE}" ]; then
        echo -e "${GREEN}✓ Local file exists:${NC}"
        cat ${WELL_KNOWN_FILE}
        echo ""
    else
        echo -e "${RED}✗ Local file not found!${NC}"
        echo ""
    fi
    
    echo "Testing public URL..."
    RESPONSE=$(curl -s https://${DOMAIN}/.well-known/openai.json || echo "FAILED")
    
    if [[ "${RESPONSE}" == *"domain_verification"* ]]; then
        echo -e "${GREEN}✓ Domain verification accessible!${NC}"
        echo "${RESPONSE}" | jq . 2>/dev/null || echo "${RESPONSE}"
    else
        echo -e "${RED}✗ Domain verification NOT accessible!${NC}"
        echo "Response: ${RESPONSE}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

manual_bearer_token() {
    echo -e "${YELLOW}[MANUAL BEARER TOKEN]${NC}"
    echo "Paste your Bearer Token (64 chars recommended):"
    read -r MANUAL_TOKEN
    
    if [ -z "${MANUAL_TOKEN}" ]; then
        echo -e "${RED}✗ Token cannot be empty!${NC}"
        return
    fi
    
    sed -i "s/^SERVER_BEARER_TOKEN=.*/SERVER_BEARER_TOKEN=${MANUAL_TOKEN}/" ${ENV_FILE}
    
    cd ${APP_DIR}
    node generate-actions.js full
    
    restart_services
    
    echo -e "${GREEN}✓ Bearer Token updated!${NC}"
}

setup_letsencrypt() {
    echo -e "${GREEN}[SETUP LET'S ENCRYPT]${NC}"
    certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}
    echo -e "${GREEN}✓ SSL activated!${NC}"
}

setup_custom_ssl() {
    echo -e "${YELLOW}[CUSTOM SSL]${NC}"
    
    mkdir -p ${PROJECT_ROOT}/ssl
    
    echo "Paste fullchain.pem (end with Ctrl+D):"
    cat > ${PROJECT_ROOT}/ssl/fullchain.pem
    
    echo "Paste privkey.pem (end with Ctrl+D):"
    cat > ${PROJECT_ROOT}/ssl/privkey.pem
    
    # Update Nginx
    cat > ${NGINX_CONF} <<'NGINXCONF'
server {
    listen 80;
    server_name files.bytrix.my.id;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name files.bytrix.my.id;
    
    ssl_certificate /opt/gpt/ssl/fullchain.pem;
    ssl_certificate_key /opt/gpt/ssl/privkey.pem;
    
    root /opt/gpt/app/public;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /actions.json {
        proxy_pass http://localhost:3000/actions.json;
    }
}
NGINXCONF

    nginx -t && systemctl restart nginx
    echo -e "${GREEN}✓ Custom SSL activated!${NC}"
}

change_s3_endpoint() {
    echo "Enter new S3 Endpoint:"
    read -r NEW_ENDPOINT
    sed -i "s|^S3_ENDPOINT=.*|S3_ENDPOINT=${NEW_ENDPOINT}|" ${ENV_FILE}
    restart_services
    echo -e "${GREEN}✓ S3 Endpoint updated!${NC}"
}

change_s3_access_key() {
    echo "Enter new S3 Access Key ID:"
    read -r NEW_KEY
    sed -i "s/^S3_ACCESS_KEY_ID=.*/S3_ACCESS_KEY_ID=${NEW_KEY}/" ${ENV_FILE}
    restart_services
    echo -e "${GREEN}✓ S3 Access Key updated!${NC}"
}

change_s3_secret_key() {
    echo "Enter new S3 Secret Access Key:"
    read -r NEW_SECRET
    sed -i "s/^S3_SECRET_ACCESS_KEY=.*/S3_SECRET_ACCESS_KEY=${NEW_SECRET}/" ${ENV_FILE}
    restart_services
    echo -e "${GREEN}✓ S3 Secret Key updated!${NC}"
}

change_s3_region() {
    echo "Enter new S3 Region:"
    read -r NEW_REGION
    sed -i "s/^S3_REGION=.*/S3_REGION=${NEW_REGION}/" ${ENV_FILE}
    restart_services
    echo -e "${GREEN}✓ S3 Region updated!${NC}"
}

change_s3_bucket() {
    echo "Enter new S3 Bucket:"
    read -r NEW_BUCKET
    sed -i "s/^S3_BUCKET=.*/S3_BUCKET=${NEW_BUCKET}/" ${ENV_FILE}
    restart_services
    echo -e "${GREEN}✓ S3 Bucket updated!${NC}"
}

test_s3_connection() {
    echo -e "${CYAN}[TEST S3 CONNECTION]${NC}"
    cd ${APP_DIR}
    node -e "
    const AWS = require('aws-sdk');
    require('dotenv').config();
    const s3 = new AWS.S3({
        endpoint: process.env.S3_ENDPOINT,
        accessKeyId: process.env.S3_ACCESS_KEY_ID,
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
        region: process.env.S3_REGION,
        s3ForcePathStyle: true
    });
    s3.listBuckets((err, data) => {
        if (err) {
            console.log('❌ Connection failed:', err.message);
        } else {
            console.log('✅ Connection successful!');
            console.log('Buckets:', data.Buckets.map(b => b.Name).join(', '));
        }
    });
    "
    read -p "Press Enter to continue..."
}

change_supabase_key() {
    echo "Enter new Supabase Service Role Key:"
    read -r NEW_KEY
    sed -i "s/^SUPABASE_SERVICE_ROLE_KEY=.*/SUPABASE_SERVICE_ROLE_KEY=${NEW_KEY}/" ${ENV_FILE}
    restart_services
    echo -e "${GREEN}✓ Supabase Key updated!${NC}"
}

generate_openapi_supabase() {
    cd ${APP_DIR}
    node generate-actions.js supabase
    echo -e "${GREEN}✓ OpenAPI (Supabase only) generated!${NC}"
}

generate_openapi_s3() {
    cd ${APP_DIR}
    node generate-actions.js s3
    echo -e "${GREEN}✓ OpenAPI (S3 only) generated!${NC}"
}

generate_openapi_full() {
    cd ${APP_DIR}
    node generate-actions.js full
    echo -e "${GREEN}✓ OpenAPI (Full Combo) generated!${NC}"
}

docker_start() {
    cd ${PROJECT_ROOT}
    docker-compose up -d
    echo -e "${GREEN}✓ Docker started!${NC}"
}

docker_stop() {
    cd ${PROJECT_ROOT}
    docker-compose down
    echo -e "${GREEN}✓ Docker stopped!${NC}"
}

docker_rebuild() {
    cd ${PROJECT_ROOT}
    docker-compose down
    docker-compose build --no-cache
    docker-compose up -d
    echo -e "${GREEN}✓ Docker rebuilt!${NC}"
}

test_all_endpoints() {
    echo -e "${CYAN}[TEST ALL ENDPOINTS]${NC}"
    
    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}✗ .env file not found!${NC}"
        return
    fi
    
    source ${ENV_FILE}
    
    echo "Testing with Bearer Token: ${SERVER_BEARER_TOKEN:0:20}..."
    echo ""
    
    # Test domain verification
    echo "1. Domain Verification:"
    curl -s https://${DOMAIN}/.well-known/openai.json | jq . || echo "FAILED"
    echo ""
    
    # Test OpenAPI
    echo "2. OpenAPI Spec:"
    curl -s https://${DOMAIN}/actions.json | jq '.info.title' || echo "FAILED"
    echo ""
    
    # Test protected endpoint
    echo "3. Protected Endpoint (without auth - should fail):"
    curl -s https://${DOMAIN}/api/supabase/tables | jq . || echo "Expected failure"
    echo ""
    
    echo "4. Protected Endpoint (with Bearer Token):"
    curl -s -H "Authorization: Bearer ${SERVER_BEARER_TOKEN}" https://${DOMAIN}/api/supabase/tables | jq . || echo "FAILED"
    echo ""
    
    read -p "Press Enter to continue..."
}

backup_all() {
    echo -e "${YELLOW}[BACKUP]${NC}"
    BACKUP_DIR="/root/gpt-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p ${BACKUP_DIR}
    
    cp -r ${APP_DIR}/.env ${BACKUP_DIR}/
    cp -r ${APP_DIR}/public ${BACKUP_DIR}/
    cp ${NGINX_CONF} ${BACKUP_DIR}/ 2>/dev/null || true
    
    echo -e "${GREEN}✓ Backup saved to: ${BACKUP_DIR}${NC}"
    read -p "Press Enter to continue..."
}

uninstall_all() {
    echo -e "${RED}[UNINSTALL]${NC}"
    echo "This will remove EVERYTHING. Are you sure? (yes/no)"
    read -r CONFIRM
    
    if [ "${CONFIRM}" != "yes" ]; then
        echo "Cancelled."
        return
    fi
    
    pm2 delete all 2>/dev/null || true
    pm2 save --force 2>/dev/null || true
    
    docker-compose -f ${PROJECT_ROOT}/docker-compose.yml down 2>/dev/null || true
    
    rm -rf ${PROJECT_ROOT}
    rm -f ${NGINX_CONF}
    rm -f /etc/nginx/sites-enabled/gpt-actions
    
    systemctl restart nginx
    
    echo -e "${GREEN}✓ Uninstalled!${NC}"
}

# Main loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1) install_native ;;
        2) install_docker ;;
        3) update_from_github ;;
        4) restart_services ;;
        5) show_logs ;;
        6) regenerate_bearer_token ;;
        7) check_domain_verification ;;
        8) manual_bearer_token ;;
        9) setup_letsencrypt ;;
        10) setup_custom_ssl ;;
        11) setup_custom_ssl ;;
        12) setup_letsencrypt ;;
        13) change_s3_endpoint ;;
        14) change_s3_access_key ;;
        15) change_s3_secret_key ;;
        16) change_s3_region ;;
        17) change_s3_bucket ;;
        18) test_s3_connection ;;
        19) change_supabase_key ;;
        20) generate_openapi_supabase ;;
        21) generate_openapi_s3 ;;
        22) generate_openapi_full ;;
        23) docker_start ;;
        24) docker_stop ;;
        25) docker_rebuild ;;
        26) test_all_endpoints ;;
        27) backup_all ;;
        28) uninstall_all ;;
        0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
