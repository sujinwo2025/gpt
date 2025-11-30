# Copilot Instructions for GPT Custom Actions Server

## 🏗️ Architecture Overview
- **Monorepo Structure:**
  - Main logic in `app/` (Express server, OpenAPI generator, public assets, logs).
  - Top-level scripts (`menu.sh`) for install/update/maintenance.
  - Nginx config (`nginx.conf`) and Docker setup (`docker-compose.yml`, `Dockerfile`).
- **Service Boundaries:**
  - `app/index.js`: Express API server, handles Supabase CRUD and S3 file operations.
  - `app/generate-actions.js`: Generates OpenAPI 3.1.0 spec based on current config.
  - Nginx: Reverse proxy, static file serving, SSL termination.
  - Docker: Containerizes both API and Nginx, with healthchecks and volume mounts.

## 🛠️ Developer Workflows
- **Install/Update:**
  - Use `menu.sh` for all setup, update, and maintenance tasks.
    - Native (PM2 + Nginx): `./menu.sh` → option 1
    - Docker: `./menu.sh` → option 2
    - Update: `./menu.sh` → option 3
- **Environment Variables:**
  - `.env` auto-generated in `$HOME/gpt/app/.env` (or `/opt/gpt/app/.env` in legacy setups).
  - Reference `.env.example` for required keys.
- **OpenAPI Spec:**
  - Regenerate with `node app/generate-actions.js full` or via menu option.
  - Served at `/actions.json`.
- **Testing:**
  - Use menu option 26 for endpoint tests.
  - Health endpoint: `/health` (no auth).
  - All `/api/*` endpoints require Bearer Token.
- **Build/Run:**
  - Native: `pm2 start ecosystem.config.js` (auto-managed by menu).
  - Docker: `docker-compose up -d --build`.

## 📦 Patterns & Conventions
- **Bearer Token Auth:**
  - All `/api/*` routes require `Authorization: Bearer <token>`.
  - Token is set in `.env` and can be regenerated via menu.
- **OpenAI Domain Verification:**
  - Served from `public/.well-known/openai.json`.
  - Domain and verification file auto-generated.
- **Supabase & S3 Integration:**
  - Credentials loaded from `.env`.
  - Supabase client: `@supabase/supabase-js`.
  - S3 client: `@aws-sdk/client-s3` (v3).
- **Error Handling:**
  - API returns structured JSON errors with `error` and `message` fields.
  - Menu script checks for required commands and permissions.
- **SSL Management:**
  - Supports Let's Encrypt and custom SSL via menu options.
  - Nginx config expects certs in `/ssl` or `/etc/letsencrypt`.

## 🔗 Integration Points
- **External Services:**
  - Supabase (CRUD, storage).
  - S3-compatible storage (AWS, DigitalOcean, MinIO).
  - OpenAI (Custom GPT integration via OpenAPI and domain verification).
- **Cross-Component Communication:**
  - Nginx proxies `/api/*` to Express server.
  - Docker containers share volumes for `.env`, public assets, logs.

## 📝 Examples
- **Add new API endpoint:**
  - Implement in `app/index.js`, document in `app/generate-actions.js` for OpenAPI.
- **Update environment:**
  - Edit `.env` or use menu options for safe updates.
- **Regenerate OpenAPI spec:**
  - Run `node app/generate-actions.js full` or use menu.

## ⚠️ Project-Specific Notes
- Always use the menu for install/update to avoid missing dependencies.
- All critical paths and files are now in `$HOME/gpt` for non-root installs.
- Healthchecks and logs are configured for both PM2 and Docker.

---

Please review and let me know if any section needs clarification or if there are undocumented patterns you want included!
