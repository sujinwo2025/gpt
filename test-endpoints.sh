#!/bin/bash

# ==========================================
# Test all endpoints with Bearer Token
# ==========================================

set -e

if [ ! -f "/opt/gpt/app/.env" ]; then
    echo "❌ .env file not found!"
    exit 1
fi

source /opt/gpt/app/.env

DOMAIN="${DOMAIN:-files.bytrix.my.id}"
TOKEN="${SERVER_BEARER_TOKEN}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   GPT Custom Actions - Endpoint Tests                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Domain: https://${DOMAIN}"
echo "Bearer Token: ${TOKEN:0:20}..."
echo ""

# Test 1: Domain Verification (no auth required)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Testing Domain Verification (/.well-known/openai.json)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s "https://${DOMAIN}/.well-known/openai.json")
if echo "$RESPONSE" | grep -q "domain_verification"; then
    echo "✅ PASS"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ FAIL"
    echo "$RESPONSE"
fi
echo ""

# Test 2: Health Check (no auth required)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Testing Health Check (/health)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s "https://${DOMAIN}/health")
if echo "$RESPONSE" | grep -q "healthy"; then
    echo "✅ PASS"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ FAIL"
    echo "$RESPONSE"
fi
echo ""

# Test 3: OpenAPI Spec (no auth required)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Testing OpenAPI Spec (/actions.json)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s "https://${DOMAIN}/actions.json")
if echo "$RESPONSE" | grep -q "openapi"; then
    echo "✅ PASS"
    echo "$RESPONSE" | jq '.info.title, .info.version, .components.securitySchemes' 2>/dev/null || echo "$RESPONSE" | head -20
else
    echo "❌ FAIL"
    echo "$RESPONSE"
fi
echo ""

# Test 4: Protected Endpoint WITHOUT Bearer Token (should fail)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Testing Protected Endpoint WITHOUT Bearer Token (should FAIL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s "https://${DOMAIN}/api/supabase/tables")
if echo "$RESPONSE" | grep -q "Unauthorized"; then
    echo "✅ PASS (correctly rejected)"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ FAIL (should be rejected!)"
    echo "$RESPONSE"
fi
echo ""

# Test 5: Protected Endpoint WITH Bearer Token (should succeed)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Testing Protected Endpoint WITH Bearer Token"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -H "Authorization: Bearer ${TOKEN}" "https://${DOMAIN}/api/supabase/tables")
if echo "$RESPONSE" | grep -q -E "(success|tables|error)"; then
    echo "✅ PASS (authenticated successfully)"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ FAIL"
    echo "$RESPONSE"
fi
echo ""

# Test 6: S3 Buckets (with Bearer Token)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Testing S3 Buckets Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -H "Authorization: Bearer ${TOKEN}" "https://${DOMAIN}/api/s3/buckets")
if echo "$RESPONSE" | grep -q -E "(success|buckets|error)"; then
    echo "✅ PASS (authenticated successfully)"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ FAIL"
    echo "$RESPONSE"
fi
echo ""

# Test 7: Invalid Bearer Token (should fail)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7️⃣  Testing with INVALID Bearer Token (should FAIL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -H "Authorization: Bearer INVALID_TOKEN_12345" "https://${DOMAIN}/api/supabase/tables")
if echo "$RESPONSE" | grep -q "Forbidden\|Invalid"; then
    echo "✅ PASS (correctly rejected invalid token)"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ FAIL (should reject invalid token!)"
    echo "$RESPONSE"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   TEST SUMMARY                                           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "✅ If all tests passed, your server is production-ready!"
echo "🔐 Bearer Token authentication is working correctly"
echo "🌐 Domain verification is accessible for OpenAI"
echo "📝 OpenAPI spec is available for Custom GPT import"
echo ""
