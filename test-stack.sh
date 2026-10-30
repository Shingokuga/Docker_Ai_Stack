#!/usr/bin/env bash
# test-stack.sh — Test de santé de tous les services de la stack
# Utilise les routes définies dans config/caddy/Caddyfile.
set -euo pipefail

cd "$(dirname "$0")"

# Charger les variables nécessaires depuis .env
if [ -f .env ]; then
    # SOURCE .env pour obtenir BASE_DOMAIN et HTTP_PORT/HTTPS_PORT
    # Les valeurs par défaut sont dans le fichier, c'est sûr de les sourcer
    . .env
fi

BASE_DOMAIN="${BASE_DOMAIN:-local}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
fail() { echo "❌ $*"; }

PASS=0
FAIL=0
TOTAL=0

test_http() {
    local name="$1"
    local url="$2"
    local expected="$3"

    TOTAL=$((TOTAL + 1))
    echo ""
    echo "--- Test HTTP: $name ---"

    local result
    result=$(curl -fsS -k --max-time 10 "$url" 2>&1)
    local exit_code=$?

    if echo "$result" | grep -q "$expected"; then
        ok "$name"
        PASS=$((TOTAL))
        PASS=$((PASS))
    else
        fail "$name (exit $exit_code)"
        echo "$result"
        FAIL=$((FAIL + 1))
    fi
}

test_container() {
    local name="$1"
    local service="$2"

    TOTAL=$((TOTAL + 1))
    echo ""
    echo "--- Test conteneur: $name ($service) ---"

    local status
    status=$(docker compose --env-file versions.env --env-file .env ps -q "$service" 2>&1)
    if [ -n "$status" ]; then
        ok "$name (running)"
        PASS=$((PASS + 1))
    else
        fail "$name (not running)"
        FAIL=$((FAIL + 1))
    fi
}

test_cmd() {
    local name="$1"
    local command="$2"
    local expected="$3"

    TOTAL=$((TOTAL + 1))
    echo ""
    echo "--- Test commande: $name ---"

    local result
    result=$(eval "$command" 2>&1)
    local exit_code=$?

    if [ -z "$expected" ] || echo "$result" | grep -q "$expected"; then
        ok "$name"
        PASS=$((PASS + 1))
    else
        fail "$name (exit $exit_code)"
        echo "$result"
        FAIL=$((FAIL + 1))
    fi
}

info "Test de la stack universelle AI..."
info "BASE_DOMAIN: $BASE_DOMAIN"
info "HTTP_PORT: $HTTP_PORT, HTTPS_PORT: $HTTPS_PORT"

# Vérifier que tous les conteneurs sont up
info "Vérification de l'état des conteneurs..."
docker compose --env-file versions.env --env-file .env ps --format json | grep -v '"Status":"exited"'

# Tests HTTP via Caddy (les vrais hôtes définis dans le Caddyfile)
test_http "Open WebUI" "http://chat-ai.${BASE_DOMAIN}:80/health" "OK"
test_http "n8n" "http://automatisation.${BASE_DOMAIN}:80/healthz" ""
test_http "LiteLLM" "http://api.${BASE_DOMAIN}:80/health/liveliness" ""
test_http "Docling" "http://documents.${BASE_DOMAIN}:80/health" ""
test_http "Caddy" "http://certificat.${BASE_DOMAIN}:80/root.crt" ""
test_http "Qdrant" "http://qdrant:6333/healthz" ""
test_http "Ollama" "http://ollama:11434/api/tags" ""
test_http "Kokoro" "http://kokoro:8880/health" ""
test_http "Whisper" "http://whisper:8000/health" ""
test_http "Langfuse Web" "http://suivi-ia.${BASE_DOMAIN}:80/api/public/health" ""
test_http "Portainer" "http://admin.${BASE_DOMAIN}:80/" ""
test_http "S3 Console" "http://stockage.${BASE_DOMAIN}:80/rustfs/console/health" ""

# Tests de conteneurs (services sans health HTTP ou non exposés)
test_container "SearXNG" "searxng"
test_container "Obscura" "obscura"
test_container "Langfuse Worker" "langfuse-worker"

# Tests de commandes dans les conteneurs
test_cmd "Postgres" "docker compose --env-file versions.env --env-file .env exec postgres pg_isready -U postgres -d postgres" ""
# Redis: utiliser REDISCLI_AUTH pour ne pas exposer le mot de passe en ligne de commande
test_cmd "Redis" "docker compose --env-file versions.env --env-file .env exec -e REDISCLI_AUTH=\$(grep REDIS_PASSWORD .env | cut -d= -f2-) redis redis-cli --no-auth-warning ping" "PONG"
test_cmd "ClickHouse" "docker compose --env-file versions.env --env-file .env exec clickhouse wget --no-verbose --tries=1 --spider http://127.0.0.1:8123/ping" ""
test_cmd "S3 API" "docker compose --env-file versions.env --env-file .env exec s3 curl -fsS http://127.0.0.1:9000/health" ""
test_cmd "n8n-worker" "docker compose --env-file versions.env --env-file .env exec n8n-worker node -e \"require('http').get('http://127.0.0.1:5678/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))\"" ""
test_cmd "langfuse-worker-health" "docker compose --env-file versions.env --env-file .env exec langfuse-worker wget -q --spider http://127.0.0.1:3030/api/health" ""

echo ""
echo "=============================================="
echo "Résultats des tests"
echo "=============================================="
echo "Total:  $TOTAL"
echo "OK:     $PASS"
echo "Échecs: $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
    echo "❌ Certains services ont échoué"
    exit 1
else
    echo "✅ Tous les tests ont réussi"
    exit 0
fi
