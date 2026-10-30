#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-/home/shingokuga/Docker_stack_universelle}"
cd "$REPO"

echo "Tests de la stack Docker..."

echo "Vérification des conteneurs..."
FAILED=0
for svc in qdrant open-webui obscura grafana prometheus alertmanager caddy nginx; do
    state=$(docker inspect --format='{{.State.Status}}' $svc 2>/dev/null || echo "stopped")
    if [[ "$state" == "running" ]]; then
        echo "  [OK] $svc"
    else
        echo "  [KO] $svc (état: $state)"
        FAILED=1
    fi
done

if [[ $FAILED -ne 0 ]]; then
    echo "Certains conteneurs ne sont pas en cours d'exécution"
    exit 1
fi

echo "Tous les conteneurs fonctionnent"
