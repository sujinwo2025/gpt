# GPT Custom Actions Server - Deployment Checklist

## 📋 Pre-Deployment

- [ ] Fresh Ubuntu 20.04/22.04 server
- [ ] Root access or sudo privileges
- [ ] Domain DNS pointed to server IP (`files.bytrix.my.id`)
- [ ] Ports 80 and 443 open in firewall

## 🚀 Installation Steps

### 1. Clone Repository
```bash
cd /opt
git clone <your-repo-url> gpt
cd gpt
chmod +x menu.sh install.sh test-endpoints.sh backup.sh
```

### 2. Run Installation
```bash
sudo ./install.sh
# Choose Native (PM2) or Docker mode
```

### 3. Save Bearer Token
**CRITICAL:** The installer will generate and display a 64-char Bearer Token.
```
Bearer Token: [64 characters]
```
- [ ] Copy this token immediately
- [ ] Save to password manager
- [ ] This is needed for Custom GPT authentication

### 4. Configure Services

#### Update .env File
```bash
nano /opt/gpt/app/.env
```

Edit these values:
```bash
# Supabase (required for DB operations)
SUPABASE_URL=https://your-actual-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhb...your-actual-key

# S3 (required for file operations)
S3_ENDPOINT=https://nyc3.digitaloceanspaces.com  # or your S3 endpoint
S3_ACCESS_KEY_ID=YOUR_ACTUAL_ACCESS_KEY
S3_SECRET_ACCESS_KEY=YOUR_ACTUAL_SECRET_KEY
S3_REGION=nyc3  # or your region
S3_BUCKET=your-bucket-name
```

#### Restart Services
```bash
cd /opt/gpt
./menu.sh
# Choose: 4) Restart semua service
```

### 5. Setup SSL Certificate

**Option A: Let's Encrypt (Recommended)**
```bash
./menu.sh
# Choose: 9) Aktifkan SSL Let's Encrypt
```

**Option B: Custom SSL**
```bash
./menu.sh
# Choose: 10) Aktifkan Custom SSL
# Paste your fullchain.pem and privkey.pem
```

### 6. Verify Installation

```bash
./test-endpoints.sh
```

Expected results:
- [ ] ✅ Domain verification accessible
- [ ] ✅ Health check returns 200
- [ ] ✅ OpenAPI spec accessible
- [ ] ✅ Protected endpoints reject requests without Bearer token
- [ ] ✅ Protected endpoints accept requests with valid Bearer token
- [ ] ✅ Invalid Bearer tokens are rejected

### 7. Manual Verification

**Domain Verification:**
```bash
curl https://files.bytrix.my.id/.well-known/openai.json
```
Expected: `{"openai":{"domain_verification":"files.bytrix.my.id"}}`

**OpenAPI Spec:**
```bash
curl https://files.bytrix.my.id/actions.json | jq .info
```
Expected: Title, version, and description

**Bearer Auth Test:**
```bash
TOKEN="your-64-char-token"
curl -H "Authorization: Bearer $TOKEN" \
  https://files.bytrix.my.id/api/supabase/tables
```
Expected: JSON response with Supabase tables or error message

## 🎯 Custom GPT Configuration

### 1. Create Custom GPT
- Go to OpenAI → My GPTs → Create a GPT
- Configure name, description, instructions

### 2. Add Actions
1. Click "Configure" → "Actions"
2. Click "Create new action"
3. Import from URL: `https://files.bytrix.my.id/actions.json`
4. Click "Import"

### 3. Setup Authentication
1. In Actions → Authentication
2. Select: **Bearer**
3. Paste your Bearer Token (64 chars from installation)
4. Click "Save"

### 4. Verify Domain
OpenAI will automatically verify:
- URL: `https://files.bytrix.my.id/.well-known/openai.json`
- Should show green checkmark ✅

### 5. Test Actions
Ask your GPT:
- "List all tables in Supabase"
- "Show me the S3 buckets"
- "Query the users table"
- "Upload a file to S3"

## ✅ Post-Deployment Checklist

### Security
- [ ] Bearer Token saved securely
- [ ] SSL certificate installed and valid
- [ ] `.env` file has correct permissions (600)
- [ ] Firewall configured (only 80, 443 open)
- [ ] Server updated: `apt update && apt upgrade -y`

### Monitoring
- [ ] PM2 or Docker running: `./menu.sh` → 5) Lihat log
- [ ] Nginx running: `systemctl status nginx`
- [ ] No errors in logs
- [ ] Health check responds: `curl https://files.bytrix.my.id/health`

### Backups
- [ ] Create initial backup: `./backup.sh`
- [ ] Setup cron for daily backups:
```bash
crontab -e
# Add: 0 2 * * * /opt/gpt/backup.sh
```

### Documentation
- [ ] Bearer Token documented in team password manager
- [ ] Server IP and credentials documented
- [ ] Supabase credentials backed up
- [ ] S3 credentials backed up

## 🔄 Maintenance Tasks

### Daily
- Check service status: `./menu.sh` → 4) Restart semua service
- Review logs for errors

### Weekly
- Run endpoint tests: `./test-endpoints.sh`
- Verify SSL expiry date
- Check disk space: `df -h`

### Monthly
- Update packages: `apt update && apt upgrade -y`
- Rotate logs if needed
- Review and cleanup old backups

## 🐛 Troubleshooting

### Domain verification fails
```bash
# Check file exists
cat /opt/gpt/app/public/.well-known/openai.json

# Check nginx serving it
curl http://localhost/.well-known/openai.json

# Check DNS
dig files.bytrix.my.id
```

### Bearer token not working
```bash
# Verify token in .env
grep SERVER_BEARER_TOKEN /opt/gpt/app/.env

# Regenerate token
./menu.sh
# Choose: 6) Generate ulang Bearer Token
```

### Server not responding
```bash
# Check service status
pm2 status                    # Native mode
docker-compose ps             # Docker mode

# Check nginx
systemctl status nginx

# View logs
pm2 logs --lines 50           # Native mode
docker-compose logs --tail=50 # Docker mode
```

### SSL issues
```bash
# Test SSL
curl -I https://files.bytrix.my.id

# Renew Let's Encrypt
certbot renew

# Check certificate
openssl s_client -connect files.bytrix.my.id:443 -servername files.bytrix.my.id
```

## 📞 Support Resources

- **Quick Reference:** See `QUICK-REFERENCE.md`
- **Full README:** See `README.md`
- **Logs Location:**
  - PM2: `/opt/gpt/app/logs/`
  - Nginx: `/var/log/nginx/gpt-*.log`
  - Docker: `docker-compose logs`

## 🎉 Production Ready

Once all checkboxes are ✅:
- Your server is production-ready
- Custom GPT can access all endpoints
- Domain is verified by OpenAI
- Bearer token authentication is working
- SSL is configured and valid

**Deploy time: ~5-10 minutes** 🚀

---

**Remember:** Keep your Bearer Token secret! It's the master key to your API.
