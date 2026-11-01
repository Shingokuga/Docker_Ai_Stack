#!/usr/bin/env bash
# test-stack.sh — Test de santé de tous les services de la stack
# Vérifie la parsabilité du compose, l'état réel des conteneurs et les points d'accès HTTP.
set -euo pipefail

cd "$(dirname "$0")"

# Parse arguments
WAIT_SECONDS=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --wait)
            WAIT_SECONDS="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Lecture clé par clé depuis .env (pas de source pour éviter les caractères spéciaux)
get_env() {
    local key="$1"
    local default="$2"
    if [ -f .env ]; then
        local val
        val=$(/usr/bin/grep -m1 "^${key}=" .env | cut -d'=' -f2-)
        if [ -n "$val" ]; then
            echo "$val"
            return 0
        fi
    fi
    echo "$default"
}

NO_GPU=$(get_env NO_GPU "0")
BASE_DOMAIN=$(get_env BASE_DOMAIN "local")
HTTPS_PORT=$(get_env HTTPS_PORT "443")

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
fail() { echo "❌ $*"; }

PASS=0
FAIL=0
TOTAL=0

# 1. Vérification que le compose est parsable et ne contient pas d'erreurs de configuration
info "Vérification de la configuration compose (./stack config)..."
if ! ./stack config > /dev/null 2>&1; then
    fail "Compose non parsable ou variables d'environnement manquantes"
    PS_JSON=""
else
    ok "Configuration compose valide"
fi

# 2. Vérification de l'état réel des conteneurs
info "État des conteneurs (./stack ps -a)..."
PS_JSON=$(./stack ps -a --format json 2>/dev/null || echo "")

# Parser la sortie JSON lignes par lignes (un objet JSON par ligne, pas un tableau)
parse_containers() {
    if command -v jq >/dev/null 2>&1; then
        echo "$PS_JSON" | jq -r '
            [.Service, .Name, .State, .Health, (.ExitCode // 0)] | join("\t")
        '
    else
        echo "$PS_JSON" | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        service = obj.get('Service', 'unknown')
        name = obj.get('Name', 'unknown')
        state = obj.get('State', 'unknown')
        health = obj.get('Health', '')
        exit_code = obj.get('ExitCode', 0)
        print(f'{service}\t{name}\t{state}\t{health}\t{exit_code}')
    except json.JSONDecodeError:
        pass
"
    fi
}

CONTAINER_DATA=$(parse_containers)

# Wait for containers to stabilize if --wait specified
if [ "$WAIT_SECONDS" -gt 0 ]; then
    info "Attente stabilisation conteneurs (max ${WAIT_SECONDS}s)..."
    ELAPSED=0
    while [ "$ELAPSED" -lt "$WAIT_SECONDS" ]; do
        PS_JSON=$(./stack ps -a --format json 2>/dev/null || echo "")
        CONTAINER_DATA=$(parse_containers)

        UNSTABLE=0
        UNSTABLE_NAMES=""
        while IFS=$'\t' read -r service name state health exit_code; do
            state_lower=$(echo "$state" | tr '[:upper:]' '[:lower:]')
            health_lower=$(echo "$health" | tr '[:upper:]' '[:lower:]')
            if [ "$state_lower" = "starting" ] || [ "$state_lower" = "restarting" ] || [ "$health_lower" = "unhealthy" ]; then
                UNSTABLE=$((UNSTABLE + 1))
                UNSTABLE_NAMES="${UNSTABLE_NAMES} ${name}"
            fi
        done <<< "$CONTAINER_DATA"

        if [ "$UNSTABLE" -eq 0 ]; then
            ok "Tous les conteneurs sont stables (${ELAPSED}s)"
            break
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    if [ "$ELAPSED" -ge "$WAIT_SECONDS" ]; then
        info "Timeout atteinte. Conteneurs non stables:${UNSTABLE_NAMES}"
        PS_JSON=$(./stack ps -a --format json 2>/dev/null || echo "")
        CONTAINER_DATA=$(parse_containers)
    fi
fi

# Analyser l'état des conteneurs
if [ -n "$CONTAINER_DATA" ]; then
    while IFS=$'\t' read -r service name state health exit_code; do
        state_lower=$(echo "$state" | tr '[:upper:]' '[:lower:]')
        health_lower=$(echo "$health" | tr '[:upper:]' '[:lower:]')

        TOTAL=$((TOTAL + 1))

        if [ "$health_lower" = "unhealthy" ]; then
            fail "Service $service ($name) : unhealthy"
            FAIL=$((FAIL + 1))
        elif [ "$state_lower" = "restarting" ]; then
            fail "Service $service ($name) : redémarrage en boucle"
            FAIL=$((FAIL + 1))
        elif [ "$state_lower" = "exited" ]; then
            if [ "$exit_code" != "0" ] && [ -n "$exit_code" ]; then
                fail "Service $service ($name) : terminé code $exit_code"
                FAIL=$((FAIL + 1))
            else
                ok "Service $service ($name) : terminé normalement (code 0)"
                PASS=$((PASS + 1))
            fi
        else
            ok "Service $service ($name) : $state"
            PASS=$((PASS + 1))
        fi
    done <<< "$CONTAINER_DATA"
else
    info "Aucun conteneur trouvé"
fi

# Vérifier les services requis sans GPU
if [ "$NO_GPU" = "1" ]; then
    # En mode sans GPU, docling-serve et comfyui sont optionnels
    for service in docling-serve comfyui; do
        has_service=$(/usr/bin/grep -c "^${service}	" <<< "$CONTAINER_DATA" || true)
        if [ "$has_service" -eq 0 ]; then
            info "Service $service : ignoré (service non démarré, mode sans GPU)"
        fi
    done
else
    # En mode GPU, tous les services doivent être présents
    for service in docling-serve comfyui; do
        has_service=$(/usr/bin/grep -c "^${service}	" <<< "$CONTAINER_DATA" || true)
        if [ "$has_service" -eq 0 ]; then
            TOTAL=$((TOTAL + 1))
            fail "Service $service : service absent"
            FAIL=$((FAIL + 1))
        fi
    done
fi

# 3. Vérification des points d'accès HTTP pour les services critiques
# Sites lus depuis le Caddyfile (noms de domaine <nom>.{$BASE_DOMAIN})
info "Vérification des points d'accès HTTP..."

# Extract site names from Caddyfile (only those ending with .{$BASE_DOMAIN})
SITE_NAMES=$(/usr/bin/grep -oP '^[a-z][a-z0-9-]*\.\{\$BASE_DOMAIN\}' caddy/Caddyfile 2>/dev/null | sed 's/\.{$BASE_DOMAIN}//' | sort -u)

if command -v curl >/dev/null 2>&1; then
    check_http() {
        local name="$1"
        local timeout=10
        TOTAL=$((TOTAL + 1))

        local http_code
        http_code=$(curl -sk -L --max-time "$timeout" \
            --resolve "${name}.${BASE_DOMAIN}:443:127.0.0.1" \
            -o /dev/null -w "%{http_code}" \
            "https://${name}.${BASE_DOMAIN}/" 2>/dev/null) || http_code="000"

        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
            ok "HTTP $name : code $http_code"
            PASS=$((PASS + 1))
        else
            fail "HTTP $name : code $http_code"
            FAIL=$((FAIL + 1))
        fi
    }

    check_certificat() {
        local name="certificat"
        local timeout=10
        TOTAL=$((TOTAL + 1))

        local http_code
        http_code=$(curl -s --max-time "$timeout" \
            --resolve "${name}.${BASE_DOMAIN}:80:127.0.0.1" \
            -o /dev/null -w "%{http_code}" \
            "http://${name}.${BASE_DOMAIN}/root.crt" 2>/dev/null) || http_code="000"

        if [ "$http_code" = "200" ]; then
            ok "Certificat /root.crt : code $http_code"
            PASS=$((PASS + 1))
        else
            fail "Certificat /root.crt : code $http_code"
            FAIL=$((FAIL + 1))
        fi
    }

    # Test each site defined in Caddyfile
    for site_name in $SITE_NAMES; do
        # Skip documents/images if their backend services aren't running
        if [ "$site_name" = "documents" ]; then
            has_service=$(/usr/bin/grep -c "^docling-serve	" <<< "$CONTAINER_DATA" || true)
            if [ "$has_service" -eq 0 ]; then
                info "HTTP documents : ignoré (docling-serve non démarré)"
                continue
            fi
        fi
        if [ "$site_name" = "images" ]; then
            has_service=$(/usr/bin/grep -c "^comfyui	" <<< "$CONTAINER_DATA" || true)
            if [ "$has_service" -eq 0 ]; then
                info "HTTP images : ignoré (comfyui non démarré)"
                continue
            fi
        fi
        check_http "$site_name"
    done

    # Test certificate endpoint separately (http://certificat.local)
    check_certificat
fi

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