#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-/home/shingokuga/Docker_stack_universelle}"
cd "$REPO"

echo "Génération des certificats SSL..."
mkdir -p certs
for svc in chat-ai navigateur-ai cockpit-ai monitoring-ai metrics-ai alertes-ai; do
    if [[ ! -f certs/${svc}.crt ]]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout certs/${svc}.key \
            -out certs/${svc}.crt \
            -subj "/C=FR/ST=France/L=Paris/O=AI Stack/CN=${svc}.example.com"
        echo "  Certificat généré: ${svc}"
    fi
done

echo "Certificats SSL prêts"

echo ""
echo "Configuration de Open WebUI (MCP)..."
if bash scripts/configure-openwebui.sh; then
    echo "  Open WebUI configuré avec succès"
else
    echo "  Avertissement: configuration Open WebUI échouée"
    echo "  Voir docs/OPEN-WEBUI-OUTILS.md pour la configuration manuelle"
fi