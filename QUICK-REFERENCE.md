# GPT Custom Actions Server - Quick Reference

## 🚦 Proxy Otomatis & Status Indikator

Status Nginx, Caddy, dan Host akan tampil di menu utama:
```
Status: Nginx 🟢 | Caddy 🔴 | Host 🟢 (192.168.x.x)
```
🟢 = aktif, 🔴 = tidak aktif

### Switch Proxy
Untuk mengganti proxy antara Nginx dan Caddy:
```bash
./menu.sh
# Pilih: 37) Switch Proxy: Nginx <-> Caddy
```
Ikuti instruksi di layar untuk memilih proxy yang ingin diaktifkan.

## 🚀 Quick Start Commands

### Native Installation
```bash
cd /opt
git clone <your-repo> gpt
cd gpt
chmod +x menu.sh install.sh
sudo ./install.sh
# Choose: 1) Native (PM2 + Nginx)
```

### Docker Installation
```bash
cd /opt
git clone <your-repo> gpt
cd gpt
chmod +x menu.sh install.sh
sudo ./install.sh
# Choose: 2) Docker (Docker-Compose)
```

### Interactive Menu
```bash
cd /opt/gpt
sudo ./menu.sh
```

## 🔑 Bearer Token

### Get Current Token
```bash
grep SERVER_BEARER_TOKEN /opt/gpt/app/.env | cut -d'=' -f2
```

### Generate New Token (64 chars)
```bash
openssl rand -base64 48 | tr -d '/+=' | head -c 64
```

### Update Token
```bash
cd /opt/gpt
./menu.sh
# Choose: 6) Generate ulang Bearer Token
```

## 🌐 Domain Verification

### Check Local File
```bash
cat /opt/gpt/app/public/.well-known/openai.json
```

### Test Public URL
```bash
curl https://files.bytrix.my.id/.well-known/openai.json
```

### Verify in Menu
```bash
./menu.sh
# Choose: 7) Cek status domain verification OpenAI
```

## 📝 OpenAPI Spec

### Generate OpenAPI
```bash
cd /opt/gpt/app
node generate-actions.js full      # Supabase + S3
node generate-actions.js supabase  # Supabase only
node generate-actions.js s3        # S3 only
```

### View Generated Spec
```bash
cat /opt/gpt/app/public/actions.json | jq .
```

### Test Public URL
```bash
curl https://files.bytrix.my.id/actions.json | jq .info
```

## 🔧 Service Management

### PM2 (Native Mode)
```bash
pm2 status                  # Check status
pm2 logs gpt-custom-actions # View logs
pm2 restart all             # Restart
pm2 stop all                # Stop
pm2 delete all              # Delete
```

### Docker Mode
```bash
cd /opt/gpt
docker-compose ps           # Status
docker-compose logs -f      # Logs
docker-compose restart      # Restart
docker-compose down         # Stop
docker-compose up -d        # Start
```

### Nginx
```bash
sudo nginx -t               # Test config
sudo systemctl status nginx # Status
sudo systemctl restart nginx # Restart
sudo systemctl reload nginx # Reload config
```

## 🧪 Testing

### Run All Tests
```bash
cd /opt/gpt
./test-endpoints.sh
```

### Manual Tests

**Domain Verification (no auth):**
```bash
curl https://files.bytrix.my.id/.well-known/openai.json
```

**Health Check (no auth):**
```bash
curl https://files.bytrix.my.id/health
```

**Protected Endpoint (with Bearer Token):**
```bash
TOKEN="your-bearer-token-here"
curl -H "Authorization: Bearer $TOKEN" \
  https://files.bytrix.my.id/api/supabase/tables
```

**Test Invalid Token (should fail):**
```bash
curl -H "Authorization: Bearer INVALID_TOKEN" \
  https://files.bytrix.my.id/api/supabase/tables
```

## 🔐 SSL Setup

### Let's Encrypt (Automatic)
```bash
./menu.sh
# Choose: 9) Aktifkan SSL Let's Encrypt
```

### Custom SSL
```bash
./menu.sh
# Choose: 10) Aktifkan Custom SSL
# Paste fullchain.pem and privkey.pem when prompted
```

## ⚙️ Configuration

### Update Environment Variables
```bash
nano /opt/gpt/app/.env
# Edit values
pm2 restart all  # or docker-compose restart
```

### Change S3 Credentials
```bash
./menu.sh
# Choose: 13-17) S3 configuration options
```

### Change Supabase Key
```bash
./menu.sh
# Choose: 19) Ganti Supabase Service Role Key
```

## 💾 Backup & Restore

### Create Backup
```bash
cd /opt/gpt
./backup.sh
# or via menu: 27) Backup semua
```

### Restore from Backup
```bash
cd /root/gpt-backups
tar -xzf gpt-backup-YYYYMMDD-HHMMSS.tar.gz
cd gpt-backup-YYYYMMDD-HHMMSS
cat backup-info.txt  # Follow instructions
```

## 🗑️ Uninstall

### Complete Removal
```bash
./menu.sh
# Choose: 28) Uninstall total bersih
```

### Manual Uninstall
```bash
pm2 delete all
sudo rm -rf /opt/gpt
sudo rm -f /etc/nginx/sites-available/gpt-actions
sudo rm -f /etc/nginx/sites-enabled/gpt-actions
sudo systemctl restart nginx
```

## 🐛 Troubleshooting

### Check Logs
```bash
# PM2
pm2 logs gpt-custom-actions --lines 100

# Docker
docker-compose logs -f --tail=100

# Nginx
sudo tail -f /var/log/nginx/gpt-error.log
```

### Test Bearer Token Auth
```bash
# Get token
TOKEN=$(grep SERVER_BEARER_TOKEN /opt/gpt/app/.env | cut -d'=' -f2)

# Test
curl -v -H "Authorization: Bearer $TOKEN" \
  https://files.bytrix.my.id/api/supabase/tables
```

### Regenerate Everything
```bash
cd /opt/gpt/app
node generate-actions.js full
pm2 restart all  # or docker-compose restart
```

### Port Already in Use
```bash
# Find process using port 3000
sudo lsof -i :3000
# Kill it
sudo kill -9 <PID>
# Restart
pm2 restart all
```

## 📱 Custom GPT Setup

1. **Import OpenAPI Spec:**
   - Go to Custom GPT → Actions
   - Click "Import from URL"
   - Enter: `https://files.bytrix.my.id/actions.json`

2. **Setup Authentication:**
   - Authentication → Bearer
   - Paste your Bearer Token (from install or menu)

3. **Verify Domain:**
   - OpenAI will automatically check: `/.well-known/openai.json`
   - Should show green checkmark

4. **Test:**
   - Ask GPT to list Supabase tables
   - Ask GPT to list S3 buckets

## 🔗 Important URLs

- Domain Verification: `https://files.bytrix.my.id/.well-known/openai.json`
- OpenAPI Spec: `https://files.bytrix.my.id/actions.json`
- Health Check: `https://files.bytrix.my.id/health`
- API Base: `https://files.bytrix.my.id/api/`

## 📋 Common Tasks

### Update from Git
```bash
cd /opt/gpt
git pull
cd app
npm install
pm2 restart all  # or docker-compose restart
```

### View Current Bearer Token
```bash
./menu.sh
# Token shown in banner, or check .env
cat /opt/gpt/app/.env | grep SERVER_BEARER_TOKEN
```

### Test S3 Connection
```bash
./menu.sh
# Choose: 18) Test koneksi S3
```

### Restart Everything
```bash
./menu.sh
# Choose: 4) Restart semua service
```

---

**Pro Tip:** Keep your Bearer Token secret! It's the key to your entire API.
