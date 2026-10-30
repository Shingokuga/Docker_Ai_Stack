#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-/home/shingokuga/Docker_stack_universelle}"
cd "$REPO"

if [[ ! -f .env ]]; then
    echo "ERREUR: .env n'existe pas"
    exit 1
fi

source <(grep -E "^(BASE_DOMAIN|HTTP_PORT|HTTPS_PORT)=" .env)
BASE_DOMAIN="${BASE_DOMAIN:-local}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"

echo "=========================================="
echo "Tests de la stack Docker"
echo "=========================================="
echo ""

TOTAL=0
PASS=0
FAIL=0

test_container() {
    local name="$1"
    local expected="${2:-running}"
    TOTAL=$((TOTAL + 1))
    state=$(docker inspect --format='{{.State.Status}}' $name 2>/dev/null || echo "stopped")
    if [[ "$state" == "$expected" ]]; then
        echo "  [OK] $name: $state"
        PASS=$((PASS + 1))
    else
        echo "  [KO] $name: $state (attendu: $expected)"
        FAIL=$((FAIL + 1))
    fi
}

test_container_running() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    state=$(docker inspect --format='{{.State.Status}}' $name 2>/dev/null || echo "stopped")
    if [[ "$state" == "running" ]]; then
        echo "  [OK] $name: running"
        PASS=$((PASS + 1))
    else
        echo "  [KO] $name: $state"
        FAIL=$((FAIL + 1))
    fi
}

echo "--- Tests conteneurs ---"
test_container "postgres" "running"
test_container "redis" "running"
test_container "qdrant" "running"
test_container "ollama" "running"
test_container "llama-server" "running"
test_container "litellm" "running"
test_container "open-webui" "running"
test_container "n8n" "running"
test_container "n8n-worker" "running"
test_container "docling-serve" "running"
test_container "searxng" "running"
test_container "portainer" "running"
test_container "caddy" "running"
test_container "obscura" "running"
test_container "obscura-mcp" "running"
test_container "kokoro" "running"
test_container "whisper" "running"
test_container "clickhouse" "running"
test_container "s3" "running"
test_container "langfuse-worker" "running"
test_container "langfuse-web" "running"
test_container "s3-init" "exited"
test_container "ollama-init" "exited"

echo ""
echo "--- Tests santé (healthcheck) ---"
for svc in postgres redis qdrant ollama llama-server litellm open-webui n8n n8n-worker docling-serve searxng kokoro whisper clickhouse s3 langfuse-worker langfuse-web; do
    TOTAL=$((TOTAL + 1))
    health=$(docker inspect --format='{{.State.Health.Status}}' $svc 2>/dev/null || echo "unknown")
    if [[ "$health" == "healthy" ]]; then
        echo "  [OK] $svc: healthy"
        PASS=$((PASS + 1))
    else
        echo "  [KO] $svc: $health"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "--- Tests endpoints web (via Caddy, TLS interne) ---"
test_web() {
    local host="$1"
    local port="$2"
    local scheme="${3:-https}"
    local expected="${4:-}"
    TOTAL=$((TOTAL + 1))
    url="${scheme}://${host}:${port}"
    if [[ -n "$expected" ]]; then
        resp=$(curl -k -s -o /tmp/test_resp.txt -w "%{http_code}" --resolve "${host}:${port}:127.0.0.1" "$url")
        if [[ "$resp" == "200" ]] && /usr/bin/grep -q "$expected" /tmp/test_resp.txt; then
            echo "  [OK] $url: 200 + contenu attendu"
            PASS=$((PASS + 1))
        else
            echo "  [KO] $url: $resp"
            FAIL=$((FAIL + 1))
        fi
    else
        resp=$(curl -k -s -o /dev/null -w "%{http_code}" --resolve "${host}:${port}:127.0.0.1" "$url")
        if [[ "$resp" == "200" ]]; then
            echo "  [OK] $url: 200"
            PASS=$((PASS + 1))
        else
            echo "  [KO] $url: $resp"
            FAIL=$((FAIL + 1))
        fi
    fi
}

test_web "chat-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "navigateur-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "cockpit-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "automatisation.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "monitoring-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "metrics-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "alertes-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "suivi-ia.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
test_web "stockage-ai.${BASE_DOMAIN}" "$HTTPS_PORT" "https" ""
# certificat. est en HTTP dans le Caddyfile
test_web "certificat.${BASE_DOMAIN}" "$HTTP_PORT" "http" ""

echo ""
echo "=========================================="
echo "Résultats: $PASS/$TOTAL réussis, $FAIL échoués"
echo "=========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi