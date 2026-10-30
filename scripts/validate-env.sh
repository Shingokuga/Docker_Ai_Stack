#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-/home/shingokuga/Docker_stack_universelle}"
cd "$REPO"

if [[ ! -f .env ]]; then
    echo "ERREUR: .env n'existe pas. Copiez .env.example vers .env"
    exit 1
fi

errors=0

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    key=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2-)

    if [[ "$line" =~ ^#[[:space:]]*\(optionnel\)[[:space:]]* ]]; then
        continue
    fi

    if [[ "$line" =~ \? ]]; then
        if [[ -z "$value" ]]; then
            echo "ERREUR: $key est requis mais vide"
            errors=$((errors + 1))
        fi
    fi
done < .env.example

if [[ $errors -gt 0 ]]; then
    echo "$errors erreurs trouvées"
    exit 1
fi

echo "Validation de l'environnement: OK"
