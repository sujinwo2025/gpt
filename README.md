# GPT Custom Actions Server - FINAL VERSION

## 🚦 Proxy Otomatis & Status Indikator

Server ini mendukung fallback otomatis ke **Caddy** jika **Nginx** gagal. Semua proses instalasi, konfigurasi SSL, dan aktivasi Caddy dilakukan otomatis tanpa intervensi manual.

Di menu utama, status service akan tampil:

```
Status: Nginx 🟢 | Caddy 🔴 | Host 🟢 (192.168.x.x)
```

🟢 = aktif, 🔴 = tidak aktif

Anda bisa melakukan **switch proxy** antara Nginx dan Caddy melalui menu:

```
[ PROXY SWITCH ]
37) Switch Proxy: Nginx <-> Caddy
```

Pilih proxy yang ingin diaktifkan, sistem akan otomatis menghentikan dan mengaktifkan service sesuai pilihan Anda.

Production-ready GPT Custom Actions server dengan:
- ✅ **Bearer Token Authentication** (OpenAI requirement)
- ✅ **Domain Verification Endpoint** untuk OpenAI
- ✅ **Supabase CRUD Operations**
- ✅ **S3 File Operations** (AWS S3, DigitalOcean Spaces, MinIO compatible)
- ✅ **Docker Support**
- ✅ **PM2 + Nginx Production Setup**
- ✅ **OpenAPI 3.1.0 Spec Generator**

## 🚀 Quick Start

### 1. Install (Native Mode - PM2 + Nginx)

```bash
cd /opt
git clone <your-repo> gpt
cd gpt
chmod +x menu.sh
./menu.sh
# Pilih: 1) Install pertama kali (Native — PM2 + Nginx)
```

### 2. Install (Docker Mode)

```bash
cd /opt
git clone <your-repo> gpt
cd gpt
chmod +x menu.sh
./menu.sh
# Pilih: 2) Install pertama kali (Docker-Compose mode)
```

### 3. Konfigurasi OpenAI Custom GPT

Setelah install, Anda akan mendapat:
- **Bearer Token**: Copy dari output install
- **Domain Verification URL**: `https://files.bytrix.my.id/.well-known/openai.json`
- **OpenAPI Spec URL**: `https://files.bytrix.my.id/actions.json`

Di Custom GPT:
1. Actions → Import from URL → `https://files.bytrix.my.id/actions.json`
2. Authentication → Bearer Token → Paste Bearer Token dari install
3. Domain Verification → Akan otomatis terverifikasi

## 🔐 Bearer Token Authentication

Semua endpoint `/api/*` HANYA bisa diakses dengan header:

```bash
Authorization: Bearer <your-64-char-token>
```

Generate ulang token:
```bash
./menu.sh
# Pilih: 6) Generate ulang Bearer Token
```

## 📁 Struktur Direktori

```
/opt/gpt/
├── app/
│   ├── index.js              # Express server
│   ├── generate-actions.js   # OpenAPI generator
│   ├── .env                  # Environment variables
│   ├── public/
│   │   └── .well-known/
│   │       └── openai.json   # Domain verification
│   └── logs/
├── docker-compose.yml
├── Dockerfile
├── nginx.conf
├── menu.sh                   # Interactive menu
└── README.md
```

## 🛠️ Menu Features

```
[ INSTALLATION ]
1) Install Native (PM2 + Nginx)
2) Install Docker
3) Update from GitHub
4) Restart services
5) View logs

[ SECURITY & OPENAI VERIFICATION ]
6) Regenerate Bearer Token (64 char)
7) Check domain verification status
8) Manual Bearer Token

[ SSL MANAGEMENT ]
9-14) Let's Encrypt / Custom SSL

[ S3 EXTERNAL ]
15-22) S3 configuration & test

[ SUPABASE STORAGE ]
23-27) Supabase config & test

[ OPENAPI GENERATOR ]
28-30) Generate OpenAPI

[ DOCKER CONTROL ]
31-33) Docker management

[ MAINTENANCE & TESTING ]
34-36) Endpoint test, backup, uninstall

[ PROXY SWITCH ]
37) Switch Proxy: Nginx <-> Caddy
```
[ SUPABASE ]
19) Change Supabase key

[ GENERATE OPENAPI 3.1.0 ]
20) Supabase only
21) S3 only
22) Full Combo

[ DOCKER CONTROL ]
23-25) Docker management

[ MAINTENANCE ]
26) Test all endpoints
27) Backup
28) Uninstall
```

## 📚 API Endpoints

### Public Endpoints
- `GET /.well-known/openai.json` - Domain verification
- `GET /actions.json` - OpenAPI spec

### Protected Endpoints (Require Bearer Token)

#### Supabase CRUD
- `GET /api/supabase/tables` - List all tables
- `POST /api/supabase/query` - Execute query
- `POST /api/supabase/insert` - Insert data
- `PUT /api/supabase/update` - Update data
- `DELETE /api/supabase/delete` - Delete data

#### S3 File Operations
- `GET /api/s3/buckets` - List buckets
- `GET /api/s3/files` - List files in bucket
- `POST /api/s3/upload` - Upload file
- `GET /api/s3/download/:key` - Download file
- `DELETE /api/s3/delete` - Delete file

## 🔧 Environment Variables

Lihat `.env.example` untuk template lengkap.

Key variables:
- `SERVER_BEARER_TOKEN` - Auto-generated 64-char token
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key
- `S3_ENDPOINT` - S3 compatible endpoint
- `S3_ACCESS_KEY_ID` - Access key
- `S3_SECRET_ACCESS_KEY` - Secret key
- `DOMAIN` - Your domain for verification

## 🐳 Docker Deployment

```bash
cd /opt/gpt
docker-compose up -d --build
```

View logs:
```bash
docker-compose logs -f
```

## 🔄 Updates

```bash
./menu.sh
# Pilih: 3) Update dari GitHub + rebuild + restart
```

## 🧪 Testing

Test semua endpoint dengan Bearer Token:
```bash
./menu.sh
# Pilih: 26) Test semua endpoint
```

Manual test:
```bash
# Domain verification (no auth required)
curl https://files.bytrix.my.id/.well-known/openai.json

# Protected endpoint (requires Bearer Token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://files.bytrix.my.id/api/supabase/tables
```

## 📦 Backup

```bash
./menu.sh
# Pilih: 27) Backup semua
```

Backup akan disimpan di: `/root/gpt-backup-YYYYMMDD-HHMMSS/`

## 🗑️ Uninstall

```bash
./menu.sh
# Pilih: 28) Uninstall total bersih
```

## 🌟 Production Ready

✅ Bearer Token Authentication  
✅ OpenAI Domain Verification  
✅ Rate Limiting  
✅ CORS configured  
✅ Helmet security headers  
✅ Morgan logging  
✅ PM2 process management  
✅ Nginx reverse proxy  
✅ SSL support (Let's Encrypt + Custom)  
✅ Docker containerization  
✅ Auto-restart on failure  
✅ Log rotation  

## 📄 License

MIT

## 🆘 Support

Untuk issues atau questions, buka issue di GitHub repository.

---

**Deploy dalam 5 menit. Production-ready. No bullshit.** 🚀
# gpt
# gpt
