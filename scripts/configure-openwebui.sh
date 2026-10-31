#!/usr/bin/env bash
set -euo pipefail

# Configure-openwebui.sh
# Configure les serveurs MCP (Obscura, Context7) dans Open WebUI via l'API admin.
# Idempotent : fusionne par info.id, ne supprime jamais les connexions existantes.
#
# Contexte vérifié dans Open WebUI v0.12.5 :
# - TOOL_SERVER_CONNECTIONS est lu UNE SEULE FOIS au 1er démarrage, ensuite la base prime
# - Les MCP sont réservés aux admins dans Open WebUI
# - Chaque utilisateur active les outils par chat dans "Intégrations"
#
# Routes utilisées :
# POST /api/v1/auths/signin          -> {token}
# GET  /api/v1/configs/tool_servers  -> {"TOOL_SERVER_CONNECTIONS":[...]}
# POST /api/v1/configs/tool_servers  -> remplace toute la liste (fusion par info.id)
#
# Connexions configurées :
# - obscura     : http://obscura-mcp:3000/mcp (navigateur)
# - context7    : https://mcp.context7.com/mcp (documentation, si clé)
# - comfyui     : (futur) serveur MCP ComfyUI
#
# Prérequis : jq installé (par bootstrap.sh)

REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERREUR: $ENV_FILE introuvable"
    exit 1
fi

get_env() {
    grep "^$1=" "$ENV_FILE" | cut -d= -f2- | head -1
}

WEBUI_ADMIN_EMAIL=$(get_env WEBUI_ADMIN_EMAIL)
WEBUI_ADMIN_PASSWORD=$(get_env WEBUI_ADMIN_PASSWORD)
OBSCURA_MCP_TOKEN=$(get_env OBSCURA_MCP_TOKEN)
CONTEXT7_API_KEY=$(get_env CONTEXT7_API_KEY)
BASE_DOMAIN=$(get_env BASE_DOMAIN)

if [[ -z "$WEBUI_ADMIN_EMAIL" || -z "$WEBUI_ADMIN_PASSWORD" ]]; then
    echo "ERREUR: WEBUI_ADMIN_EMAIL ou WEBUI_ADMIN_PASSWORD non défini dans .env"
    exit 1
fi

echo "Connexion à Open WebUI..."

# Méthode: curl via le réseau Docker (le plus sûr)
exec_cmd() {
    ./stack exec -T open-webui curl -s -k -X "$1" \
        -H "Authorization: Bearer ***" \
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
token=$(echo "$login_resp" | jq -r '.token' 2>/dev/null)
if [[ -z "$token" ]]; then
    echo "ERREUR: Connexion échouée"
    echo "Réponse: $login_resp"
    exit 1
fi

echo "Connecté. Configuration des serveurs MCP..."

# Récupérer la liste existante des connexions MCP
existing=$(exec_cmd GET "$token" "" "http://localhost:8080/api/v1/configs/tool_servers")
echo "$existing" > /tmp/openwebui_existing_connections.json

# Fonction pour fusionner les connexions MCP par info.id
merge_connections() {
    local existing_file="$1"
    local obscura_conn="$2"
    local context7_conn="$3"

    python3 -c "
import json

existing = json.load(open('$existing_file'))
if isinstance(existing, dict) and 'TOOL_SERVER_CONNECTIONS' in existing:
    existing = existing['TOOL_SERVER_CONNECTIONS']
elif not isinstance(existing, list):
    existing = []

obscura = json.loads('''$obscura_conn''')
context7 = json.loads('''$context7_conn''')

# Fusionner: garder les autres connexions, ajouter/mettre à jour obscura et context7
merged = []
for conn in existing:
    if conn.get('info', {}).get('id') in ['obscura', 'context7']:
        continue  # Sera ajouté en version mise à jour
    merged.append(conn)

merged.append(obscura)
merged.append(context7)

print(json.dumps(merged))
"
}

# Construire les connexions MCP
obscura_conn=$(cat <<OBSCURA_JSON
{
    "type": "mcp",
    "url": "http://obscura-mcp:3000/mcp",
    "path": "",
    "auth_type": "bearer",
    "key": "$OBSCURA_MCP_TOKEN",
    "config": {"enable": true},
    "info": {
        "id": "obscura",
        "name": "Navigateur (Obscura)",
        "description": "Navigation web, lecture de pages, formulaires, captures d'écran et PDF."
    }
}
OBSCURA_JSON
)

if [[ -n "$CONTEXT7_API_KEY" ]]; then
    context7_conn=$(cat <<CONTEXT7_JSON
{
    "type": "mcp",
    "url": "https://mcp.context7.com/mcp",
    "path": "",
    "auth_type": "bearer",
    "key": "$CONTEXT7_API_KEY",
    "config": {"enable": true},
    "info": {
        "id": "context7",
        "name": "Documentation (Context7)",
        "description": "Recherche et génération de documentation technique."
    }
}
CONTEXT7_JSON
)
else
    context7_conn=$(cat <<CONTEXT7_JSON
{
    "type": "mcp",
    "url": "https://mcp.context7.com/mcp",
    "path": "",
    "auth_type": "bearer",
    "key": "",
    "config": {"enable": false},
    "info": {
        "id": "context7",
        "name": "Documentation (Context7)",
        "description": "Recherche et génération de documentation technique."
    }
}
CONTEXT7_JSON
)
fi

# Fusionner et POST
merged=$(merge_connections /tmp/openwebui_existing_connections.json "$obscura_conn" "$context7_conn")
echo "$merged" > /tmp/openwebui_merged_connections.json

resp=$(exec_cmd POST "$token" "$(echo "$merged" | jq -c '.')" "http://localhost:8080/api/v1/configs/tool_servers")
echo "Configuration envoyée."

# Vérifier
final=$(exec_cmd GET "$token" "" "http://localhost:8080/api/v1/configs/tool_servers")
echo "Connexions MCP configurées:"
echo "$final" | jq -c '.[] | {id: .info.id, name: .info.name, enabled: .config.enable}'

echo "Configuration terminée."