#!/usr/bin/env bash
# test-stack.sh — Test de santé de tous les services de la stack
# Utilise les routes définies dans caddy/Caddyfile.
set -euo pipefail

cd "$(dirname "$0")"

# Lecture clé par clé depuis .env (pas de source pour éviter les caractères spéciaux)
get_env() {
    local key="$1"
    local default="$2"
    if [ -f .env ]; then
        local val
        val=$(grep -m1 "^${key}=" .env | cut -d'=' -f2-)
        if [ -n "$val" ]; then
            echo "$val"
            return 0
        fi
    fi
    echo "$default"
}

BASE_DOMAIN=$(get_env BASE_DOMAIN "local")
HTTP_PORT=$(get_env HTTP_PORT "80")
HTTPS_PORT=$(get_env HTTPS_PORT "443")

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
fail() { echo "❌ $*"; }

PASS=0
FAIL=0
TOTAL=0

test_http() {
    local name="$1"
    local host="$2"
    local scheme="$3"
    local port="$4"
    local path="$5"

    TOTAL=$((TOTAL + 1))

    local result
    local exit_code=0
    result=$(curl --resolve "${host}:${port}:127.0.0.1" -k -fsS -m 5 "${scheme}://${host}:${port}${path}" 2>&1) || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        ok "$name"
        PASS=$((PASS + 1))
    else
        fail "$name (curl exit $exit_code)"
        FAIL=$((FAIL + 1))
    fi
}

info "Test de la stack universelle AI..."
info "BASE_DOMAIN: $BASE_DOMAIN"
info "HTTP_PORT: $HTTP_PORT, HTTPS_PORT: $HTTPS_PORT"

# Vérifier que les conteneurs sont up
info "État des conteneurs (./stack ps)..."
./stack ps --format json > /dev/null 2>&1 || true

# Tests HTTP via Caddy (les hôtes définis dans caddy/hostnames.txt)
while IFS= read -r hostname; do
    # Ignorer les lignes vides et les commentaires
    [ -z "$hostname" ] && continue
    case "$hostname" in
        \#*) continue ;;
    esac

    if [ "$hostname" = "certificat" ]; then
        # Hôte en HTTP simple
        test_http "$hostname" "certificat.${BASE_DOMAIN}" "http" "$HTTP_PORT" "/root.crt"
    else
        # Hôtes en HTTPS avec certificat interne
        test_http "$hostname" "${hostname}.${BASE_DOMAIN}" "https" "$HTTPS_PORT" "/"
    fi
done < caddy/hostnames.txt

echo ""
echo "=============================================="
echo "Résultats des tests"
echo "=============================================="
echo "Total:  $TOTAL"
echo "OK:     $PASS"
echo "Échecs: $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
    echo "❌ Certains tests ont échoué"
    exit 1
else
    echo "✅ Tous les tests ont réussi"
    exit 0
fi
