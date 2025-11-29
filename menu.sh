# Fungsi: Switch Proxy antara Nginx dan Caddy
switch_proxy() {
    echo -e "${CYAN}[SWITCH PROXY]${NC}"
    STATUS_NGINX="$(systemctl is-active nginx 2>/dev/null)"
    STATUS_CADDY="$(systemctl is-active caddy 2>/dev/null)"
    echo "Status saat ini:"
    echo " - Nginx : $STATUS_NGINX"
    echo " - Caddy : $STATUS_CADDY"
    echo "Pilih proxy yang ingin diaktifkan:"
    echo "1) Nginx"
    echo "2) Caddy"
    read -p "Pilihan [1/2]: " PILIH_PROXY
    if [ "$PILIH_PROXY" = "1" ]; then
        echo "Menonaktifkan Caddy (stop), mengaktifkan Nginx..."
        systemctl stop caddy 2>/dev/null || true
        systemctl start nginx 2>/dev/null || true
        sleep 2
        if systemctl is-active --quiet nginx; then
            echo -e "${GREEN}✓ Nginx sudah aktif!${NC}"
            echo "Caddy hanya di-stop, bisa diaktifkan lagi kapan saja."
        else
            echo -e "${RED}✗ Gagal mengaktifkan Nginx!${NC}"
        fi
    elif [ "$PILIH_PROXY" = "2" ]; then
        echo "Menonaktifkan Nginx (stop), mengaktifkan Caddy..."
        systemctl stop nginx 2>/dev/null || true
        systemctl start caddy 2>/dev/null || true
        sleep 2
        if systemctl is-active --quiet caddy; then
            echo -e "${GREEN}✓ Caddy sudah aktif!${NC}"
            echo "Nginx hanya di-stop, bisa diaktifkan lagi kapan saja."
        else
            echo -e "${RED}✗ Gagal mengaktifkan Caddy!${NC}"
        fi
    else
        echo "Pilihan tidak valid."
    fi
    read -p "Tekan Enter untuk kembali ke menu..."
}
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

# Safely set or insert a key=value in .env (handles any characters)
set_env_var() {
    KEY="$1"
    VAL="$2"
    FILE="${ENV_FILE}"
    mkdir -p "$(dirname "$FILE")"
    touch "$FILE"
    awk -v k="$KEY" -v v="$VAL" 'BEGIN{found=0}
        $0 ~ "^" k "=" {print k "=" v; found=1; next}
        {print}
        END{if(!found) print k "=" v}
    ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}

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

        # Ensure privacy policy page exists
        if [ ! -f "/opt/gpt/app/public/privacy-policy.html" ]; then
                echo "[AUTO] Creating privacy policy page"
                cat > /opt/gpt/app/public/privacy-policy.html <<'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Privacy Policy</title><style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif;margin:40px;line-height:1.6;color:#0f172a}h1{margin-bottom:8px}small{color:#64748b}code{background:#f1f5f9;padding:2px 6px;border-radius:4px}a{color:#2563eb;text-decoration:none}a:hover{text-decoration:underline}</style><meta name="robots" content="noindex"><meta name="description" content="Privacy Policy for files.bytrix.my.id"></head><body><h1>Privacy Policy</h1><small>files.bytrix.my.id</small><p>Halaman ini menjelaskan bagaimana server ini menangani data. Sistem ini menggunakan Bearer Token untuk autentikasi API, dan tidak menyimpan data sensitif pengguna di luar kebutuhan operasional.</p><h2>Data yang Diproses</h2><ul><li>Permintaan API (endpoint, waktu, dan status) untuk keperluan log.</li><li>Konfigurasi server (mis. S3/Supabase) disimpan di berkas <code>.env</code> pada server.</li></ul><h2>Keamanan</h2><ul><li>Autentikasi via <code>Authorization: Bearer &lt;token&gt;</code>.</li><li>Reverse proxy Nginx dan rate-limit di backend.</li></ul><p>Hubungi admin jika ada pertanyaan.</p><p><a href="/">Kembali ke beranda</a></p><footer><small>&copy; files.bytrix.my.id</small></footer></body></html>
HTML
        fi

    # Inform user about structure
    echo "[AUTO] Structure ensured. PROJECT_ROOT=${PROJECT_ROOT} APP_DIR=${APP_DIR}"
}

# Colors
## Fungsi: Install dan aktifkan Caddy otomatis jika Nginx gagal
install_caddy_otomatis() {
    echo -e "${YELLOW}[CADDY FALLBACK OTOMATIS]${NC}"
    # Install Caddy jika belum ada
    if ! command -v caddy >/dev/null 2>&1; then
        echo "Menginstall Caddy..."
        apt update && apt install -y debian-keyring debian-archive-keyring curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | apt-key add -
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt update && apt install -y caddy
    fi

    # Reuse SSL dari Nginx jika ada
    SSL_PATH="/opt/gpt/ssl"
    if [ -f "$SSL_PATH/fullchain.pem" ] && [ -f "$SSL_PATH/privkey.pem" ]; then
        echo "SSL ditemukan, akan digunakan untuk Caddy."
    else
        echo "SSL tidak ditemukan, Caddy akan berjalan tanpa SSL."
    fi

    # Buat konfigurasi Caddy
    CADDYFILE="/etc/caddy/Caddyfile"
    DOMAIN_CADDY="${DOMAIN}"
    cat > "$CADDYFILE" <<EOF
${DOMAIN_CADDY} {
    root * /opt/gpt/app/public
    encode gzip
    file_server
    @wellknown path /.well-known/*
    handle @wellknown {
        file_server
    }
    @api path /api/*
    reverse_proxy @api localhost:3000
    @actions path /actions.json
    reverse_proxy @actions localhost:3000
EOF
    # Tambahkan SSL jika ada
    if [ -f "$SSL_PATH/fullchain.pem" ] && [ -f "$SSL_PATH/privkey.pem" ]; then
        echo "    tls $SSL_PATH/fullchain.pem $SSL_PATH/privkey.pem" >> "$CADDYFILE"
    else
        echo "    tls internal" >> "$CADDYFILE"
    fi
    echo "}" >> "$CADDYFILE"

    # Restart Caddy
    systemctl restart caddy
    sleep 2
    if systemctl is-active --quiet caddy; then
        echo -e "${GREEN}✓ Caddy sudah online dan aktif sebagai fallback!${NC}"
    else
        echo -e "${RED}✗ Gagal mengaktifkan Caddy!${NC}"
    fi
}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║   ██████╗ ██╗   ██╗████████╗██████╗ ██╗██╗  ██╗                      ║"
    echo "║   ██╔══██╗██║   ██║╚══██╔══╝██╔══██╗██║╚██╗██╔╝                      ║"
    echo "║   ██████╔╝██║   ██║   ██║   ██████╔╝██║ ╚███╔╝                       ║"
    echo "║   ██╔═══╝ ██║   ██║   ██║   ██╔═══╝ ██║ ██╔██╗                       ║"
    echo "║   ██║     ╚██████╔╝   ██║   ██║     ██║██╔╝ ██╗                      ║"
    echo "║   ╚═╝      ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝                      ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ Custom Actions Server – files.bytrix.my.id                           ║"
    echo "║ Bearer Token • Domain Verification • Supabase • S3                   ║"
    echo "║ Path: /opt/gpt                                                      ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_menu() {
    banner
    # Status indikator
    STATUS_NGINX="$(systemctl is-active nginx 2>/dev/null)"
    STATUS_CADDY="$(systemctl is-active caddy 2>/dev/null)"
    STATUS_HOST="$(hostname -I | awk '{print $1}')"
    ICON_NGINX="${RED}🔴${NC}"; [ "$STATUS_NGINX" = "active" ] && ICON_NGINX="${GREEN}🟢${NC}"
    ICON_CADDY="${RED}🔴${NC}"; [ "$STATUS_CADDY" = "active" ] && ICON_CADDY="${GREEN}🟢${NC}"
    ICON_HOST="${GREEN}🟢${NC}"
    echo -e "Status: Nginx $ICON_NGINX  |  Caddy $ICON_CADDY  |  Host $ICON_HOST ($STATUS_HOST)"
    echo "-------------------------------------------------------------"
    echo -e "${CYAN}[ INSTALL & UPDATE ]${NC}"
    echo " 1)  Install pertama kali (Native — PM2 + Nginx)"
    echo " 2)  Install pertama kali (Docker-Compose mode)"
    echo " 3)  Update dari GitHub + rebuild + restart"
    echo " 4)  Restart semua service"
    echo " 5)  Lihat log real-time"
    echo ""
    echo -e "${YELLOW}[ SECURITY & VERIFICATION ]${NC}"
    echo " 6)  Generate ulang Bearer Token (64 char) → otomatis update OpenAPI"
    echo " 7)  Cek status domain verification OpenAI"
    echo " 8)  Ganti Bearer Token manual (paste sendiri)"
    echo ""
    echo -e "${GREEN}[ SSL MANAGEMENT ]${NC}"
    echo " 9)  Aktifkan SSL Let's Encrypt"
    echo "10) Aktifkan Custom SSL → Paste fullchain.pem + privkey.pem"
    echo "11) Ganti Custom SSL"
    echo "12) Kembali ke Let's Encrypt"
    echo "13) Overwrite SSL (fullchain.pem & privkey.pem)"
    echo "14) Overwrite SSL pakai Let's Encrypt (certbot)"
    echo ""
    echo -e "${BLUE}[ S3 STORAGE ]${NC}"
    echo "15) Change S3 Endpoint"
    echo "16) Change S3 Access Key ID"
    echo "17) Change S3 Secret Access Key"
    echo "18) Change S3 Region"
    echo "19) Change Default Bucket"
    echo "20) Test koneksi S3"
    echo "21) Test S3 List Objects (v3)"
    echo "22) Test Buat File ke S3 (input nama file)"
    echo ""
    echo -e "${MAGENTA}[ SUPABASE STORAGE ]${NC}"
    echo "23) Ganti Supabase Service Role Key"
    echo "24) Ganti Supabase URL"
    echo "25) Test koneksi Supabase"
    echo "26) Ganti Supabase Bucket Name"
    echo "27) Test Supabase Storage (list objects)"
    echo ""
    echo -e "${CYAN}[ OPENAPI GENERATOR ]${NC}"
    echo "28) Generate → Hanya Supabase CRUD"
    echo "29) Generate → Hanya S3 File Operations"
    echo "30) Generate → Full Combo (default)"
    echo ""
    echo -e "${YELLOW}[ DOCKER CONTROL ]${NC}"
    echo "31) Start Docker-Compose"
    echo "32) Stop Docker-Compose"
    echo "33) Rebuild Docker tanpa cache"
    echo ""
    echo -e "${RED}[ MAINTENANCE & TESTING ]${NC}"
    echo "34) Test semua endpoint (dengan Bearer Token)"
    echo "35) Backup semua (termasuk Bearer Token)"
    echo "36) Uninstall total bersih"
    echo ""
    echo -e "${CYAN}[ PROXY SWITCH ]${NC}"
    echo "37) Switch Proxy: Nginx <-> Caddy"
    echo ""
    echo -e "${NC}[ LAINNYA ]${NC}"
    echo " 0)  Keluar"
    echo ""
    echo -n "Pilih menu: "
}

generate_bearer_token() {
    openssl rand -base64 48 | tr -d '/+=' | head -c 64
}

install_native() {
    echo -e "${GREEN}[INSTALL NATIVE MODE]${NC}"
    ensure_structure
        echo -n "Overwrite SSL (fullchain.pem & privkey.pem)? [yes/no]: "
        read -r OVERWRITE_SSL

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
SUPABASE_BUCKET=public

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
    # Ensure basic index.html to avoid 403 on root
    if [ ! -f "/opt/gpt/app/public/index.html" ]; then
        cat > /opt/gpt/app/public/index.html <<'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Custom Actions Server</title><style>body{font-family:Arial;background:#0e1117;color:#f0f3f7;padding:40px;line-height:1.5}code{background:#1b2330;padding:4px 6px;border-radius:4px}a{color:#4ea1ff;text-decoration:none}a:hover{text-decoration:underline}footer{margin-top:40px;font-size:12px;opacity:.6}</style></head><body><h1>Custom Actions Server</h1><p>Domain verification file: <code>/.well-known/openai.json</code></p><p>OpenAPI spec: <a href="/actions.json">/actions.json</a></p><p>API base: <code>/api/...</code> (Bearer token required)</p><footer>Generated automatically at install time.</footer></body></html>
HTML
    fi
    cat > ${NGINX_CONF} <<'NGINXCONF'
banner() {
    # Small, colorful banner
    echo -e "${RED}G${YELLOW}P${GREEN}T${CYAN} ${MAGENTA}C${BLUE}R${YELLOW}U${GREEN}D${NC}"
    echo -e "${CYAN}Custom Actions • Bearer • Domain • Supabase • S3${NC}"
    echo -e "${BLUE}/opt/gpt • files.bytrix.my.id${NC}"
    echo ""
}
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
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
    # Safer PM2 startup (avoid piping shell prompt artifacts)
    if command -v systemctl >/dev/null 2>&1; then
        pm2 startup systemd -u $(whoami) --hp $(eval echo ~$USER) >/dev/null 2>&1 || true
    else
        # Fallback generic startup output parsing
        START_CMD=$(pm2 startup | grep -E "pm2 .*startup" | tail -n 1)
        if [ -n "$START_CMD" ]; then
            eval "$START_CMD" || true
        fi
    fi
    
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
    echo -n "Overwrite SSL (fullchain.pem & privkey.pem)? [yes/no]: "
    read -r OVERWRITE_SSL

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
SUPABASE_BUCKET=public
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
    SKIP_PAUSE=1
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
    if [ -f package-lock.json ]; then
        echo "Detected package-lock.json → running npm ci"
        npm ci || npm install
    else
        echo "Running npm install"
        npm install
    fi

    # Ensure scripts are executable
    if [ -f "${PROJECT_ROOT}/menu.sh" ]; then
        chmod +x "${PROJECT_ROOT}/menu.sh" || true
    fi
    if [ -f "${PROJECT_ROOT}/install.sh" ]; then
        chmod +x "${PROJECT_ROOT}/install.sh" || true
    fi
    echo "[AUTO] chmod +x applied to menu.sh and install.sh"

    # DO NOT overwrite .env during update
    # if [ -f "${ENV_FILE}" ]; then
    #     echo "[INFO] .env file preserved."
    # fi

    if [ -f "${PROJECT_ROOT}/docker-compose.yml" ] && command -v docker-compose >/dev/null 2>&1; then
        docker-compose down || true
        docker-compose up -d --build || true
    else
        if command -v pm2 >/dev/null 2>&1; then
            pm2 restart all || true
        else
            echo -e "${YELLOW}Note:${NC} pm2 not found; skipping process restart."
        fi
    fi

    echo -e "${GREEN}✓ Update complete (git pull/reset + npm install + restart, .env preserved)!${NC}"
    # Auto-restart menu.sh after update for seamless UX
    if [ -f "${PROJECT_ROOT}/menu.sh" ]; then
        exec "${PROJECT_ROOT}/menu.sh"
    elif [ -f "$0" ]; then
        exec "$0"
    else
        echo -e "${RED}Gagal auto-restart menu.sh: file tidak ditemukan!${NC}"
    fi
}

restart_services() {
    echo -e "${YELLOW}[RESTART SERVICES]${NC}"
    
    if docker ps > /dev/null 2>&1 && docker ps | grep -q gpt; then
        docker-compose -f ${PROJECT_ROOT}/docker-compose.yml restart
    else
        pm2 restart all
    fi

    # Restart Nginx, jika gagal aktifkan Caddy otomatis
    systemctl restart nginx 2>/dev/null || true
    sleep 2
    if ! systemctl is-active --quiet nginx; then
        echo -e "${RED}Nginx gagal, mengaktifkan Caddy sebagai fallback...${NC}"
        install_caddy_otomatis
    fi
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
    
    echo "---"
    echo "[1] Root HTTP"
    curl -I http://${DOMAIN} || true
    echo ""
    echo "[2] Root HTTPS"
    curl -I https://${DOMAIN} || true
    echo ""
    echo "[3] Domain verification HTTP"
    curl -s http://${DOMAIN}/.well-known/openai.json | jq . 2>/dev/null || curl -s http://${DOMAIN}/.well-known/openai.json || true
    echo ""
    echo "[4] Domain verification HTTPS"
    curl -s https://${DOMAIN}/.well-known/openai.json | jq . 2>/dev/null || curl -s https://${DOMAIN}/.well-known/openai.json || true
    echo ""
    echo "[5] OpenAPI HTTP title"
    curl -s http://${DOMAIN}/actions.json | jq '.info.title' 2>/dev/null || curl -s http://${DOMAIN}/actions.json || true
    echo ""
    echo "[6] OpenAPI HTTPS title"
    curl -s https://${DOMAIN}/actions.json | jq '.info.title' 2>/dev/null || curl -s https://${DOMAIN}/actions.json || true
    echo ""
    echo "[7] Localhost with Host header (bypass DNS)"
    curl -I -H "Host: ${DOMAIN}" http://127.0.0.1/ || true
    echo ""
    echo "[8] Localhost verification"
    curl -s -H "Host: ${DOMAIN}" http://127.0.0.1/.well-known/openai.json | jq . 2>/dev/null || curl -s -H "Host: ${DOMAIN}" http://127.0.0.1/.well-known/openai.json || true
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
    # Preserve existing index.html or create if missing
    if [ ! -f "/opt/gpt/app/public/index.html" ]; then
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Custom Actions Server</title></head><body><h1>Custom Actions Server</h1></body></html>' > /opt/gpt/app/public/index.html
    fi
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
    index index.html;
    location /.well-known/ { allow all; }
    # Privacy Policy routes (space-friendly)
    location = /privacy%20policy { try_files /privacy-policy.html =404; }
    location = /privacy-policy { try_files /privacy-policy.html =404; }
    location = /privacy { try_files /privacy-policy.html =404; }
    # Privacy Policy routes (space-friendly)
    location = /privacy%20policy { try_files /privacy-policy.html =404; }
    location = /privacy-policy { try_files /privacy-policy.html =404; }
    location = /privacy { try_files /privacy-policy.html =404; }
    location / {
        try_files $uri $uri/ /index.html;
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
    set_env_var "S3_ENDPOINT" "${NEW_ENDPOINT}"
    restart_services
    echo -e "${GREEN}✓ S3 Endpoint updated!${NC}"
}

change_s3_access_key() {
    echo "Enter new S3 Access Key ID:"
    read -r NEW_KEY
    set_env_var "S3_ACCESS_KEY_ID" "${NEW_KEY}"
    restart_services
    echo -e "${GREEN}✓ S3 Access Key updated!${NC}"
}

change_s3_secret_key() {
    echo "Enter new S3 Secret Access Key:"
    read -r NEW_SECRET
    set_env_var "S3_SECRET_ACCESS_KEY" "${NEW_SECRET}"
    restart_services
    echo -e "${GREEN}✓ S3 Secret Key updated!${NC}"
}

change_s3_region() {
    echo "Enter new S3 Region:"
    read -r NEW_REGION
    set_env_var "S3_REGION" "${NEW_REGION}"
    restart_services
    echo -e "${GREEN}✓ S3 Region updated!${NC}"
}

change_s3_bucket() {
    echo "Enter new S3 Bucket:"
    read -r NEW_BUCKET
    set_env_var "S3_BUCKET" "${NEW_BUCKET}"
    restart_services
    echo -e "${GREEN}✓ S3 Bucket updated!${NC}"
}

test_s3_connection() {
    echo -e "${CYAN}[TEST S3 CONNECTION]${NC}"
    cd ${APP_DIR}
        # Ensure AWS SDK v3 is installed
        if ! npm ls @aws-sdk/client-s3 >/dev/null 2>&1; then
                echo "Installing @aws-sdk/client-s3 ..."
                npm i -s @aws-sdk/client-s3 >/dev/null 2>&1 || npm i -s @aws-sdk/client-s3
        fi
        node -e "
        const { S3Client, ListBucketsCommand } = require('@aws-sdk/client-s3');
        require('dotenv').config();
        const endpoint = process.env.S3_ENDPOINT;
        const region = process.env.S3_REGION || 'us-east-1';
        const config = { region };
        if (endpoint) config.endpoint = endpoint;
        if (process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY) {
            config.credentials = {
                accessKeyId: process.env.S3_ACCESS_KEY_ID,
                secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
            };
        }
        const s3 = new S3Client(config);
        s3.send(new ListBucketsCommand({}))
            .then(data => {
                console.log('✅ Connection successful!');
                const names = (data.Buckets || []).map(b => b.Name);
                console.log('Buckets:', names.join(', '));
            })
            .catch(err => {
                console.log('❌ Connection failed:', err.name || err.code, '-', err.message);
            });
        "
    read -p "Press Enter to continue..."
}

test_s3_list_objects() {
        echo -e "${CYAN}[TEST S3 LIST OBJECTS - AWS SDK v3]${NC}"
        cd ${APP_DIR}
        if ! npm ls @aws-sdk/client-s3 >/dev/null 2>&1; then
                echo "Installing @aws-sdk/client-s3 ..."
                npm i -s @aws-sdk/client-s3 >/dev/null 2>&1 || npm i -s @aws-sdk/client-s3
        fi
        # Read envs
        if [ -f "${ENV_FILE}" ]; then
                # shellcheck disable=SC1090
                source "${ENV_FILE}"
        fi
        echo "Bucket (default: ${S3_BUCKET:-<unset>}):"
        read -r INPUT_BUCKET
        BUCKET_TO_USE="${INPUT_BUCKET:-${S3_BUCKET}}"
        if [ -z "${BUCKET_TO_USE}" ]; then
                echo -e "${RED}✗ S3_BUCKET belum diset dan tidak ada input bucket${NC}"
                read -p "Press Enter to continue..."; return
        fi
        echo "Prefix (opsional, default kosong):"
        read -r INPUT_PREFIX
        echo "maxKeys (default 10):"
        read -r INPUT_MAX
        MAX_KEYS=${INPUT_MAX:-10}
        node -e "
        const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');
        require('dotenv').config();
        const endpoint = process.env.S3_ENDPOINT;
        const region = process.env.S3_REGION || 'us-east-1';
        const config = { region };
        if (endpoint) config.endpoint = endpoint;
        if (process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY) {
            config.credentials = {
                accessKeyId: process.env.S3_ACCESS_KEY_ID,
                secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
            };
        }
        const s3 = new S3Client(config);
        const Bucket = process.env.__BUCKET;
        const Prefix = process.env.__PREFIX || undefined;
        const MaxKeys = parseInt(process.env.__MAX_KEYS || '10', 10);
        s3.send(new ListObjectsV2Command({ Bucket, Prefix, MaxKeys }))
            .then(data => {
                console.log('✅ ListObjectsV2 success');
                const list = (data.Contents || []).map(o => (String(o.Key) + ' (' + String(o.Size || 0) + 'B)'));
                if (list.length === 0) console.log('Objects: <empty>');
                else console.log('Objects:\n - ' + list.join('\n - '));
            })
            .catch(err => {
                console.log('❌ Failed:', err.name || err.code, '-', err.message);
            });
        " __BUCKET="$BUCKET_TO_USE" __PREFIX="$INPUT_PREFIX" __MAX_KEYS="$MAX_KEYS"
        echo ""
        read -p "Press Enter to continue..."
}

change_supabase_key() {
    echo "Enter new Supabase Service Role Key:"
    read -r NEW_KEY
    set_env_var "SUPABASE_SERVICE_ROLE_KEY" "${NEW_KEY}"
    restart_services
    echo -e "${GREEN}✓ Supabase Key updated!${NC}"
}

change_supabase_url() {
    echo "Enter new Supabase URL (e.g., https://xyz.supabase.co):"
    read -r NEW_URL
    set_env_var "SUPABASE_URL" "${NEW_URL}"
    restart_services
    echo -e "${GREEN}✓ Supabase URL updated!${NC}"
}

change_supabase_bucket() {
    echo "Enter Supabase Storage Bucket Name (e.g., public):"
    read -r NEW_BUCKET
    if [ -z "${NEW_BUCKET}" ]; then
        echo -e "${RED}✗ Bucket name cannot be empty${NC}"
        return
    fi
    set_env_var "SUPABASE_BUCKET" "${NEW_BUCKET}"
    restart_services
    echo -e "${GREEN}✓ Supabase Bucket updated!${NC}"
}

test_supabase_connection() {
    echo -e "${CYAN}[TEST SUPABASE CONNECTION]${NC}"
    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}✗ .env file not found!${NC}"
        return
    fi
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    if [ -z "${SUPABASE_URL}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY}" ]; then
        echo -e "${RED}✗ SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing in .env${NC}"
        return
    fi
    echo "URL: ${SUPABASE_URL}"
    echo "Testing REST endpoint with service role key..."
    # Expect HTTP 200/204/404; failures like connection refused or 401 indicate issues
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        "${SUPABASE_URL}/rest/v1/") || HTTP_CODE="000"
    if [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "204" ] || [ "${HTTP_CODE}" = "404" ]; then
        echo -e "${GREEN}✓ Supabase REST reachable (HTTP ${HTTP_CODE})${NC}"
        echo "Try querying a table with: /rest/v1/<table>?select=*"
    else
        echo -e "${RED}✗ Supabase REST unreachable (HTTP ${HTTP_CODE})${NC}"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

test_supabase_storage() {
    echo -e "${CYAN}[TEST SUPABASE STORAGE]${NC}"
    if [ ! -f "${ENV_FILE}" ]; then
        echo -e "${RED}✗ .env tidak ditemukan!${NC}"
        return
    fi
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    if [ -z "${SUPABASE_URL}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY}" ] || [ -z "${SUPABASE_BUCKET}" ]; then
        echo -e "${RED}✗ SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_BUCKET belum diset di .env${NC}"
        return
    fi
    echo "URL: ${SUPABASE_URL}"
    echo "Bucket: ${SUPABASE_BUCKET}"
    TMP_OUT="/tmp/supa_list_$$.json"
    HTTP_CODE=$(curl -s -o "${TMP_OUT}" -w "%{http_code}" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d '{"prefix":"","limit":50,"offset":0,"sortBy":{"column":"name","order":"asc"}}' \
        "${SUPABASE_URL}/storage/v1/object/list/${SUPABASE_BUCKET}" || echo "000")
    if [ "${HTTP_CODE}" = "200" ]; then
        echo -e "${GREEN}✓ Berhasil mengambil daftar objek (HTTP 200)${NC}"
        if command -v jq >/dev/null 2>&1; then
            echo "Objects:"
            jq -r '.[]?.name' "${TMP_OUT}" | sed 's/^/ - /'
        else
            echo "Response (raw):"
            cat "${TMP_OUT}"
        fi
    else
        echo -e "${RED}✗ Gagal list objek (HTTP ${HTTP_CODE})${NC}"
        echo "Response:"
        cat "${TMP_OUT}"
    fi
    rm -f "${TMP_OUT}" 2>/dev/null || true
    echo ""
    read -p "Press Enter to continue..."
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
    
    # shellcheck disable=SC1090
    source ${ENV_FILE}
    
    TOK="${SERVER_BEARER_TOKEN}"
    BASE="https://${DOMAIN}"
    echo "Using Bearer: ${TOK:0:12}... (masked)"
    echo "Domain: ${DOMAIN}"
    echo ""
    
    # Helper: show status and brief body
    show() {
        NAME="$1"; shift
        URL="$1"; shift
        AUTH="$1"; shift
        echo "- ${NAME}: ${URL}"
        if [ "${AUTH}" = "auth" ]; then
            CODE=$(curl -s -o /tmp/_out_$$ -w "%{http_code}" -H "Authorization: Bearer ${TOK}" "${URL}")
        else
            CODE=$(curl -s -o /tmp/_out_$$ -w "%{http_code}" "${URL}")
        fi
        echo "  HTTP ${CODE}"
        if command -v jq >/dev/null 2>&1; then
            jq -r '.[0]?, .info?.title?, .success?, .status?, .error? // empty' /tmp/_out_$$ 2>/dev/null | sed 's/^/  /' || head -n 3 /tmp/_out_$$ | sed 's/^/  /'
        else
            head -n 3 /tmp/_out_$$ | sed 's/^/  /'
        fi
        rm -f /tmp/_out_$$ 2>/dev/null || true
        echo ""
    }
    
    echo "[Public checks]"
    show "Health"        "${BASE}/health"            "noauth"
    show "Verification"  "${BASE}/.well-known/openai.json" "noauth"
    show "OpenAPI"       "${BASE}/actions.json"      "noauth"
    
    echo "[Protected (expect 401/403 without token)]"
    show "Tables (no auth)" "${BASE}/api/supabase/tables" "noauth"
    
    echo "[Protected with Bearer]"
    show "Tables"          "${BASE}/api/supabase/tables" "auth"
    show "S3 Buckets"      "${BASE}/api/s3/buckets"      "auth"
    show "S3 Files"        "${BASE}/api/s3/files?bucket=${S3_BUCKET}&maxKeys=10" "auth"
    show "Supabase Files"  "${BASE}/api/supabase/storage/files?bucket=${SUPABASE_BUCKET}&limit=10" "auth"
    
    echo "[Presign examples]"
    if [ -n "${S3_BUCKET}" ]; then
        SAMPLE_KEY="sample.txt"
        show "S3 Presign GET" "${BASE}/api/s3/presign?bucket=${S3_BUCKET}&key=${SAMPLE_KEY}&mode=get" "auth"
        show "S3 Presign PUT" "${BASE}/api/s3/presign?bucket=${S3_BUCKET}&key=${SAMPLE_KEY}&mode=put" "auth"
    else
        echo "- Skip presign: S3_BUCKET not set"
        echo ""
    fi
    
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

overwrite_ssl() {
    setup_custom_ssl
}

overwrite_ssl_letsencrypt() {
    setup_letsencrypt
}

test_create_file_logic() {
    echo -e "${CYAN}[TEST BUAT FILE KE S3]${NC}"
    cd "${APP_DIR}" || return 1

    # Install SDK kalau belum ada
    if [ ! -d "node_modules/@aws-sdk/client-s3" ]; then
        echo -e "${YELLOW}Menginstall @aws-sdk/client-s3 ...${NC}"
        npm i -s @aws-sdk/client-s3 >/dev/null 2>&1 || {
            echo -e "${RED}Gagal install @aws-sdk/client-s3${NC}"
            return 1
        }
    fi

    echo -n "Masukkan nama file (contoh: test-gpt.txt): "
    read -r FILE_NAME
    [[ -z "$FILE_NAME" ]] && {
        echo -e "${RED}✗ Nama file tidak boleh kosong!${NC}"
        return 1
    }

    [[ -z "$S3_BUCKET" ]] && {
        echo -e "${RED}✗ Variabel S3_BUCKET belum di-set di .env!${NC}"
        return 1
    }

    echo -e "${YELLOW}Mengupload file → s3://$S3_BUCKET/$FILE_NAME${NC}"

    # <<< VERSI FINAL YANG BENAR 100% >>>
    node <<'NODEJS' "$FILE_NAME"
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
require('dotenv').config();

const fileName = process.argv[1];
const bucket   = process.env.S3_BUCKET;
const endpoint = process.env.S3_ENDPOINT || null;
const region   = process.env.S3_REGION || 'auto';

const config = { region };
if (endpoint) config.endpoint = endpoint;
if (process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY) {
    config.credentials = {
        accessKeyId: process.env.S3_ACCESS_KEY_ID,
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
    };
}

const client = new S3Client(config);

const params = {
    Bucket: bucket,
    Key: fileName,
    Body: `Hello dari GPT! File test upload ke S3.\nWaktu: ${new Date().toISOString()}\n`,
    ContentType: 'text/plain'
};

(async () => {
    try {
        await client.send(new PutObjectCommand(params));
        console.log('\n\x1b[32m✓ BERHASIL! File terupload ke S3\x1b[0m');
        console.log('   Bucket : \x1b[1m' + bucket + '\x1b[0m');
        console.log('   Key    : \x1b[1m' + fileName + '\x1b[0m');

        let url = 'https://' + bucket;
        if (endpoint && endpoint.includes('cloudflare')) {
            url += '.r2.cloudflarestorage.com';
        }
        url += '/' + encodeURIComponent(fileName);
        console.log('   URL    : \x1b[1m' + url + '\x1b[0m\n');
    } catch (err) {
        console.log('\n\x1b[31m✗ GAGAL upload ke S3!\x1b[0m');
        console.log('   Error  : \x1b[31m' + (err.name || 'Unknown') + '\x1b[0m');
        console.log('   Pesan  : \x1b[31m' + (err.message || err) + '\x1b[0m');
        if (err.$metadata?.httpStatusCode) {
            console.log('   HTTP   : \x1b[31m' + err.$metadata.httpStatusCode + '\x1b[0m');
        }
        process.exit(1);
    }
})();
NODEJS
    # <<< SELESAI >>>

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Test upload ke S3 berhasil!${NC}"
    else
        echo -e "${RED}✗ Test upload gagal! (lihat error di atas)${NC}"
    fi

    read -p "Tekan Enter untuk melanjutkan..."
}

# Main loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1) install_native ;;
        2) install_docker ;;
        3) update_from_github ; SKIP_PAUSE=1 ;;
        4) restart_services ;;
        5) show_logs ;;
        6) regenerate_bearer_token ;;
        7) check_domain_verification ;;
        8) manual_bearer_token ;;
        9) setup_letsencrypt ;;
        10) setup_custom_ssl ;;
        11) setup_custom_ssl ;;
        12) setup_letsencrypt ;;
        13) overwrite_ssl ;;
        14) overwrite_ssl_letsencrypt ;;
        15) change_s3_endpoint ;;
        16) change_s3_access_key ;;
        17) change_s3_secret_key ;;
        18) change_s3_region ;;
        19) change_s3_bucket ;;
        20) test_s3_connection ;;
        21) test_s3_list_objects ;;
        22) test_create_file_logic ;;
        23) change_supabase_key ;;
        24) change_supabase_url ;;
        25) test_supabase_connection ;;
        26) change_supabase_bucket ;;
        27) test_supabase_storage ;;
        28) generate_openapi_supabase ;;
        29) generate_openapi_s3 ;;
        30) generate_openapi_full ;;
        31) docker_start ;;
        32) docker_stop ;;
        33) docker_rebuild ;;
        34) test_all_endpoints ;;
        35) backup_all ;;
        36) uninstall_all ;;
        37) switch_proxy ;;
        0) exit 0 ;;
        esac
    done
