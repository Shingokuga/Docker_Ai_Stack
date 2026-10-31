#!/usr/bin/env bash
# gen-secrets.sh — Génère les secrets aléatoires pour la stack universelle
# Remplit uniquement les clés VIDE dans .env, ne modifie jamais les valeurs déjà remplies.
set -euo pipefail

ENV_FILE="${1:-.env}"
cd "$(dirname "$ENV_FILE")"
ENV_FILE="$(basename "$ENV_FILE")"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ $ENV_FILE non trouvé"
    exit 1
fi

gen_hex() {
    openssl rand -hex 24
}

gen_base64() {
    # openssl rand -base64 32 puis nettoyage des caractères spéciaux / + =
    openssl rand -base64 32 | tr -d '/+='
}

gen_pk() {
    # Clé publique Langfuse format pk-lf-xxx
    echo "pk-lf-$(gen_base64 | head -c 40)"
}

gen_sk() {
    # Clé secrète Langfuse format sk-lf-xxx
    echo "sk-lf-$(gen_base64 | head -c 40)"
}

gen_email() {
    echo "admin@$(gen_base64 | head -c 12).ai"
}

gen_pass() {
    echo "$(gen_base64 | head -c 16)"
}

gen_sk_prefix() {
    echo "sk-$(gen_base64)"
}

fill_secret() {
    local key="$1"
    local generator="$2"
    local value

    # Vérifie si la clé est déjà remplie
    value=$(grep -E "^${key}=" "$ENV_FILE" | cut -d'=' -f2-)
    if [ -n "$value" ]; then
        return 0  # Déjà rempli, ne pas toucher
    fi

    local new_value
    new_value=$($generator)
    # Remplace la ligne vide par la valeur générée
    sed -i "s|^${key}=|${key}=${new_value}|" "$ENV_FILE"
}

# Secrets critiques (hex, utilisés dans les URLs)
fill_secret "POSTGRES_PASSWORD" gen_hex
fill_secret "REDIS_PASSWORD" gen_hex
fill_secret "CLICKHOUSE_PASSWORD" gen_hex

# Secrets base64
fill_secret "QDRANT_API_KEY" gen_base64
fill_secret "LITELLM_MASTER_KEY" gen_sk_prefix
fill_secret "LITELLM_SALT_KEY" gen_base64
fill_secret "WEBUI_SECRET_KEY" gen_base64
fill_secret "N8N_ENCRYPTION_KEY" gen_base64
fill_secret "NEXTAUTH_SECRET" gen_base64
fill_secret "LANGFUSE_SALT" gen_base64
fill_secret "SEARXNG_SECRET" gen_base64

# Langfuse encryption key (64 hex)
fill_secret "LANGFUSE_ENCRYPTION_KEY" "openssl rand -hex 32"

# S3 credentials
fill_secret "S3_ROOT_USER" "echo admin"
fill_secret "S3_ROOT_PASSWORD" gen_hex

# Obscura CDP token (48 caractères hex = 24 octets >= 32 octets requis)
fill_secret "OBSCURA_CDP_TOKEN" gen_hex
# Obscura MCP token (id. pour le serveur MCP interne http://obscura-mcp:3000/mcp)
fill_secret "OBSCURA_MCP_TOKEN" gen_hex

# Open WebUI admin
# Email par défaut si vide ; mot de passe >= 24 caractères (gen_pass24)
gen_pass24() {
    openssl rand -base64 32 | tr -d '/+=' | head -c 32
}
fill_secret "WEBUI_ADMIN_EMAIL" "echo admin@stack.local"
fill_secret "WEBUI_ADMIN_PASSWORD" gen_pass24

# Langfuse init headless
fill_secret "LANGFUSE_INIT_ORG_ID" "echo org-default"
fill_secret "LANGFUSE_INIT_PROJECT_ID" "echo proj-default"
fill_secret "LANGFUSE_INIT_PROJECT_PUBLIC_KEY" gen_pk
fill_secret "LANGFUSE_INIT_PROJECT_SECRET_KEY" gen_sk
fill_secret "LANGFUSE_INIT_USER_EMAIL" gen_email
fill_secret "LANGFUSE_INIT_USER_PASSWORD" gen_pass

echo "✅ Secrets générés dans $ENV_FILE"
chmod 600 "$ENV_FILE"
