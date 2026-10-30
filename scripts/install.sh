#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-/home/shingokuga/Docker_stack_universelle}"
cd "$REPO"

if [[ ! -f .env ]]; then
  echo "Copiant .env.example -> .env"
  cp .env.example .env
fi

echo "Génération des secrets manquants..."
bash scripts/gen-secrets.sh

echo "Validation de l'environnement..."
bash scripts/validate-env.sh || exit 1

echo "Vérification de l'environnement Docker..."
bash scripts/bootstrap.sh

echo "Récupération des images..."
docker compose pull --parallel

echo "Démarrage de la stack..."
docker compose up -d

# Configuration post-install (inclut configure-openwebui.sh)
echo "Configuration post-install..."
bash scripts/post-install.sh

echo "Tests de fumée..."
bash scripts/test-stack.sh

echo ""
echo "=========================================="
echo "Installation terminée avec succès !"
echo "=========================================="
echo ""
echo "Accès :"
echo "  Web:  https://chat-ai.$(grep '^BASE_DOMAIN=' .env | cut -d= -f2)"
echo "  Obscura: https://navigateur-ai.$(grep '^BASE_DOMAIN=' .env | cut -d= -f2)"
echo "  Cockpit: https://cockpit-ai.$(grep '^BASE_DOMAIN=' .env | cut -d= -f2)"
echo "  Grafana: https://monitoring-ai.$(grep '^BASE_DOMAIN=' .env | cut -d= -f2)"
echo "  Métriques: https://metrics-ai.$(grep '^BASE_DOMAIN=' .env | cut -d= -f2)"
echo "  Alertes: https://alertes-ai.$(grep '^BASE_DOMAIN=' .env | cut -d= -f2)"
echo ""
echo "Secrets générés : voir le fichier .env"
echo "Logs: docker compose logs -f <service>"
