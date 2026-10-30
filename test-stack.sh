#!/usr/bin/env bash
# test-stack.sh — Test de santé de tous les services de la stack
set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="."

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
fail() { echo "❌ $*"; }

PASS=0
FAIL=0
TOTAL=0

test_service() {
    local name="$1"
    local command="$2"
    local expected="$3"

    TOTAL=$((TOTAL + 1))
    echo ""
    echo "--- Test: $name ---"

    local result
    result=$(eval "$command" 2>&1)
    local exit_code=$?

    if echo "$result" | grep -q "$expected"; then
        ok "$name"
        PASS=$((PASS + 1))
    else
        fail "$name (exit $exit_code)"
        echo "$result"
        FAIL=$((FAIL + 1))
    fi
}

info "Test de la stack universelle AI..."

# Vérifier que tous les conteneurs sont up
info "Vérification de l'état des conteneurs..."
docker compose --env-file versions.env --env-file .env ps --format json | grep -v '"Status":"exited"'

# Test des services
test_service "Open WebUI" "curl -fsS http://localhost:8088/health" "OK"
test_service "n8n" "curl -fsS http://localhost:8088/automatisation/healthz" ""
test_service "LiteLLM" "curl -fsS http://localhost:8088/api/health/liveliness" ""
test_service "Docling" "curl -fsS http://localhost:8088/documents/health" ""
test_service "SearXNG" "curl -fsS http://localhost:8088/search/healthz" ""
test_service "Caddy" "curl -fsS http://localhost:8088/" ""
test_service "Qdrant" "curl -fsS http://localhost:8088/vecteurs/healthz" ""
test_service "Ollama" "curl -fsS http://localhost:8088/ollama/api/tags" ""
test_service "Kokoro" "curl -fsS http://localhost:8088/tts/health" ""
test_service "Whisper" "curl -fsS http://localhost:8088/stt/health" ""
test_service "Postgres" "docker compose exec postgres pg_isready -U postgres -d postgres" ""
test_service "Redis" "docker compose exec redis redis-cli --no-auth-warning -a \$(grep REDIS_PASSWORD .env | cut -d= -f2) ping" "PONG"
test_service "ClickHouse" "docker compose exec clickhouse wget --no-verbose --tries=1 --spider http://127.0.0.1:8123/ping" ""
test_service "S3 (RustFS)" "docker compose exec s3 curl -fsS http://127.0.0.1:9000/health" ""
test_service "Portainer" "docker compose exec portainer wget -q --spider http://127.0.0.1:9000/" ""
test_service "Langfuse Web" "docker compose exec langfuse-web wget -q --spider http://\$HOSTNAME:3000/api/public/health" ""
test_service "Langfuse Worker" "docker compose exec langfuse-worker wget -q --spider http://127.0.0.1:3030/api/health" ""

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
