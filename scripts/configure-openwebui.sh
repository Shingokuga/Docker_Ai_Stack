#!/usr/bin/env bash
set -euo pipefail

# Configure-openwebui.sh
# Configure les serveurs MCP (Obscura, Context7) dans Open WebUI via l'API admin.
# Idempotent : fusionne par info.id, ne supprime jamais les connexions existantes.
#
# Routes utilisées :
# POST /api/v1/auths/signin          -> {token}
# GET  /api/v1/configs/tool_servers  -> {"TOOL_SERVER_CONNECTIONS":[...]}
# POST /api/v1/configs/tool_servers  -> {"TOOL_SERVER_CONNECTIONS":[...]} (fusion par info.id)
#
# Connexions configurées :
# - obscura     : http://obscura-mcp:3000/mcp (navigateur)
# - context7    : https://mcp.context7.com/mcp (documentation, si clé)
#
# Prérequis : jq installé (par bootstrap.sh)

REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERREUR: $ENV_FILE introuvable" >&2
    exit 1
fi

get_env() {
    grep "^$1=" "$ENV_FILE" | cut -d= -f2- | head -1 || true
}

WEBUI_ADMIN_EMAIL=$(get_env WEBUI_ADMIN_EMAIL)
WEBUI_ADMIN_PASSWORD=$(get_env WEBUI_ADMIN_PASSWORD)
OBSCURA_MCP_TOKEN=$(get_env OBSCURA_MCP_TOKEN)
CONTEXT7_API_KEY=$(get_env CONTEXT7_API_KEY)

if [[ -z "$WEBUI_ADMIN_EMAIL" || -z "$WEBUI_ADMIN_PASSWORD" ]]; then
    echo "ERREUR: WEBUI_ADMIN_EMAIL ou WEBUI_ADMIN_PASSWORD non défini dans .env" >&2
    exit 1
fi

if [[ -z "$OBSCURA_MCP_TOKEN" ]]; then
    echo "ERREUR: OBSCURA_MCP_TOKEN absent ou vide dans .env" >&2
    exit 1
fi

echo "Connexion à Open WebUI..."

# Méthode: curl via le réseau Docker (le plus sûr)
exec_cmd() {
    ./stack exec -T open-webui curl -s -k -X "$1" \
        -H "Authorization: Bearer $2" \
        -H "Content-Type: application/json" \
        ${3:+"-d" "$3"} \
        "$4"
}

exec_cmd_noauth() {
    ./stack exec -T open-webui curl -s -k -X "$1" \
        -H "Content-Type: application/json" \
        ${2:+"-d" "$2"} \
        "$3"
}

# Connexion
login_json=$(jq -n --arg e "$WEBUI_ADMIN_EMAIL" --arg p "$WEBUI_ADMIN_PASSWORD" '{email:$e,password:$p}')
login_resp=$(exec_cmd_noauth POST "$login_json" "http://localhost:8080/api/v1/auths/signin")
token=$(echo "$login_resp" | jq -r '.token // empty' 2>/dev/null || true)
if [[ -z "$token" ]]; then
    echo "ERREUR: Connexion échouée" >&2
    # Extraire le détail si la réponse est un objet JSON valide
    detail=$(echo "$login_resp" | jq -r '
        if type == "object" then
            if .detail then
                if (.detail | type) == "string" then .detail
                elif (.detail | type) == "array" then
                    [.detail[] | if .msg then .msg elif type == "string" then . else "erreur inconnue" end] | join("; ")
                else "erreur inconnue" end
            else "réponse inattendue" end
        else "réponse inattendue" end' 2>/dev/null || true)
    if [[ -z "$detail" ]]; then
        detail="réponse inattendue"
    fi
    echo "$detail" >&2
    exit 1
fi

echo "Connecté. Configuration des serveurs MCP..."

# Récupérer la liste existante des connexions MCP (objet avec TOOL_SERVER_CONNECTIONS)
existing=$(exec_cmd GET "$token" "" "http://localhost:8080/api/v1/configs/tool_servers")

# Valider la réponse du GET : doit être un objet JSON avec TOOL_SERVER_CONNECTIONS en tableau
if ! echo "$existing" | jq -e 'type == "object" and (.TOOL_SERVER_CONNECTIONS | type == "array")' >/dev/null 2>&1; then
    echo "ERREUR: lecture de la configuration Open WebUI impossible" >&2
    detail=$(echo "$existing" | jq -r '
        if type == "object" then
            if .detail then
                if (.detail | type) == "string" then .detail
                elif (.detail | type) == "array" then
                    [.detail[] | if .msg then .msg elif type == "string" then . else "erreur inconnue" end] | join("; ")
                else "erreur inconnue" end
            else "réponse inattendue" end
        else "réponse inattendue" end' 2>/dev/null || true)
    if [[ -z "$detail" ]]; then
        detail="réponse inattendue"
    fi
    echo "$detail" >&2
    exit 1
fi

existing_list=$(echo "$existing" | jq -c '.TOOL_SERVER_CONNECTIONS' 2>/dev/null || true)
if [[ -z "$existing_list" || "$existing_list" == "null" ]]; then
    existing_list="[]"
fi

# Construire les connexions MCP avec type "mcp" (requis par l'API)
obscura_conn=$(jq -n \
    --arg key "$OBSCURA_MCP_TOKEN" \
    '{url: "http://obscura-mcp:3000/mcp", path: "", auth_type: "bearer", key: $key, type: "mcp", config: {enable: true}, info: {id: "obscura", name: "Navigateur (Obscura)"}}')

if [[ -n "$CONTEXT7_API_KEY" ]]; then
    context7_conn=$(jq -n \
        --arg key "$CONTEXT7_API_KEY" \
        '{url: "https://mcp.context7.com/mcp", path: "", auth_type: "bearer", key: $key, type: "mcp", config: {enable: true}, info: {id: "context7", name: "Documentation (Context7)"}}')
else
    context7_conn=$(jq -n \
        '{url: "https://mcp.context7.com/mcp", path: "", auth_type: "bearer", key: "", type: "mcp", config: {enable: false}, info: {id: "context7", name: "Documentation (Context7)"}}')
fi

# Fusion par info.id en jq : garder les connexions existantes dont l'id n'est pas obscura/context7
merged=$(jq -n \
    --argjson existing "$existing_list" \
    --argjson obscura "$obscura_conn" \
    --argjson context7 "$context7_conn" \
    '[$existing[] | select(.info.id != "obscura" and .info.id != "context7")] + [$obscura, $context7]')

# POST avec le corps objet (TOOL_SERVER_CONNECTIONS)
resp=$(exec_cmd POST "$token" "$(jq -n --argjson list "$merged" '{TOOL_SERVER_CONNECTIONS: $list}')" "http://localhost:8080/api/v1/configs/tool_servers")

# Vérifier que le POST a été accepté
if ! echo "$resp" | jq -e 'type == "object" and (.TOOL_SERVER_CONNECTIONS | type == "array")' >/dev/null 2>&1; then
    echo "ERREUR: Open WebUI a refusé la configuration" >&2
    # Extraire les messages d'erreur sans exposer .input ni la réponse brute
    detail_msgs=$(echo "$resp" | jq -r '
        if type == "object" then
            if .detail then
                if (.detail | type) == "string" then .detail
                elif (.detail | type) == "array" then
                    [.detail[] | if .msg then .msg elif type == "string" then . else "erreur inconnue" end] | join("; ")
                else "erreur inconnue" end
            else "réponse inattendue" end
        else "réponse inattendue" end' 2>/dev/null || true)
    if [[ -z "$detail_msgs" ]]; then
        detail_msgs="réponse inattendue"
    fi
    echo "$detail_msgs" >&2
    exit 1
fi

echo "Configuration envoyée."

# Vérification finale
final=$(exec_cmd GET "$token" "" "http://localhost:8080/api/v1/configs/tool_servers")
echo "Connexions MCP configurées:"
echo "$final" | jq -r '.TOOL_SERVER_CONNECTIONS[] | "\(.info.id): \(.info.name) (enable: \(.config.enable))"' 2>/dev/null || true

echo "Configuration terminée."