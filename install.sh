#!/usr/bin/env bash
# install.sh — Installation de la stack universelle AI
# Vérifie les prérequis, configure les permissions, génère les secrets et lance la stack.
# Les paquets système et Docker doivent déjà être installés (voir bootstrap.sh).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err() { echo "❌ $*" >&2; }

# -------------------------------------------------------
# a) Vérification des prérequis
# -------------------------------------------------------
verify_prereqs() {
    info "Vérification des prérequis système..."

    # Docker
    if ! command -v docker >/dev/null 2>&1; then
        err "docker non trouvé. Lancez bootstrap.sh d'abord."
        exit 1
    fi
    ok "docker trouvé"

    # docker compose v2
    if ! docker compose version >/dev/null 2>&1; then
        err "docker compose v2 non trouvé. Lancez bootstrap.sh d'abord."
        exit 1
    fi
    ok "docker compose v2 trouvé"

    # Groupe docker
    if ! groups | grep -q docker; then
        warn "Vous n'êtes pas dans le groupe docker. Lancez bootstrap.sh ou : sudo usermod -aG docker $USER"
    fi
    ok "Groupe docker OK"

    # git-lfs
    if ! command -v git-lfs >/dev/null 2>&1; then
        warn "git-lfs non trouvé — les modèles GGUF ne seront pas téléchargés"
    fi
    ok "Prérequis vérifiés"
}

# -------------------------------------------------------
# b) Vérification des ressources
# -------------------------------------------------------
check_resources() {
    info "Vérification des ressources..."

    local mem_gb
    mem_gb=$(grep -P '^MemTotal:' /proc/meminfo | awk '{print int($2/1048576)}')
    info "RAM détectée : ${mem_gb} Go"
    if [ "$mem_gb" -lt 16 ]; then
        warn "RAM < 16 Go — la stack fonctionnera mais certaines tâches seront lentes"
    fi
    ok "RAM OK"

    local disk_gb
    disk_gb=$(df -BG . | tail -n1 | awk '{print $4}' | tr -d 'G')
    info "Espace disque libre : ${disk_gb} Go"
    if [ "$disk_gb" -lt 100 ]; then
        warn "Espace disque < 100 Go — il faut au moins 100 Go pour les modèles et données"
    fi
    ok "Disque OK"
}

# -------------------------------------------------------
# c) Lecture de DATA_DIR depuis .env
# -------------------------------------------------------
load_data_dir() {
    if [ -f .env ]; then
        local extracted
        extracted=$(grep -E "^DATA_DIR=" .env | head -n1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -n "$extracted" ]; then
            DATA_DIR="$extracted"
            info "DATA_DIR lu depuis .env : $DATA_DIR"
            return 0
        fi
    fi
    DATA_DIR="./data"
    info "DATA_DIR par défaut : $DATA_DIR"
}

# -------------------------------------------------------
# d) Création des répertoires de données avec permissions
# Seuls les bind mounts du compose pour data/ (pas docling, kokoro, langfuse, litellm, searxng)
# -------------------------------------------------------
create_data_dirs() {
    info "Création des répertoires de données ($DATA_DIR)..."

    local run_as=""
    if [ "$(id -u)" -ne 0 ]; then
        run_as="sudo"
    fi

    $run_as mkdir -p "$DATA_DIR"

    # postgres (999:999)
    $run_as mkdir -p "$DATA_DIR/postgres"
    $run_as chown -R 999:999 "$DATA_DIR/postgres"

    # redis (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/redis"

    # qdrant (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/qdrant"

    # ollama (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/ollama"

    # models (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/models"

    # open-webui (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/open-webui"

    # n8n (1000:1000)
    $run_as mkdir -p "$DATA_DIR/n8n"
    $run_as chown -R 1000:1000 "$DATA_DIR/n8n"

    # n8n_shared (1000:1000)
    $run_as mkdir -p "$DATA_DIR/n8n_shared"
    $run_as chown -R 1000:1000 "$DATA_DIR/n8n_shared"

    # portainer (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/portainer"

    # caddy (root, pas de chown)
    $run_as mkdir -p "$DATA_DIR/caddy"

    # whisper (1000:1000)
    $run_as mkdir -p "$DATA_DIR/whisper"
    $run_as chown -R 1000:1000 "$DATA_DIR/whisper"

    # clickhouse/data et logs (101:101)
    $run_as mkdir -p "$DATA_DIR/clickhouse/data"
    $run_as chown -R 101:101 "$DATA_DIR/clickhouse/data"
    $run_as mkdir -p "$DATA_DIR/clickhouse/logs"
    $run_as chown -R 101:101 "$DATA_DIR/clickhouse/logs"

    # s3 (10001:10001)
    $run_as mkdir -p "$DATA_DIR/s3"
    $run_as chown -R 10001:10001 "$DATA_DIR/s3"

    ok "Répertoires de données créés avec les permissions correctes"
}

# -------------------------------------------------------
# e) Génération des secrets
# -------------------------------------------------------
generate_secrets() {
    if [ -f .env ]; then
        info ".env existe déjà — génération des secrets ignorée"
        return 0
    fi

    info "Copie de .env.example vers .env"
    cp .env.example .env

    if [ -f scripts/gen-secrets.sh ]; then
        info "Génération des secrets..."
        bash scripts/gen-secrets.sh
        ok "Secrets générés"
    else
        warn "scripts/gen-secrets.sh manquant — secrets non générés"
    fi
}

# -------------------------------------------------------
# f) Démarrage de la stack
# -------------------------------------------------------
start_stack() {
    info "Pull des images (peut prendre quelques minutes)..."
    if ! docker compose --env-file versions.env --env-file .env pull; then
        err "Échec du pull d'au moins une image. Vérifiez les tags dans versions.env."
        exit 1
    fi
    ok "Images téléchargées"

    info "Démarrage de la stack..."
    docker compose --env-file versions.env --env-file .env up -d
    ok "Stack démarrée !"

    echo ""
    echo "🌐 URLs de la stack (https) :"
    echo "  Chat AI : https://chat-ai.${BASE_DOMAIN:-local}"
    echo "  n8n Automation : https://automatisation.${BASE_DOMAIN:-local}"
    echo "  Langfuse Monitoring : https://suivi-ia.${BASE_DOMAIN:-local}"
    echo "  Portainer Admin : https://admin.${BASE_DOMAIN:-local}"
    echo "  API : https://api.${BASE_DOMAIN:-local}"
    echo "  Documents : https://documents.${BASE_DOMAIN:-local}"
    echo "  Stockage S3 : https://stockage.${BASE_DOMAIN:-local}"
    echo ""
    echo "Pour vérifier la stack : ./test-stack.sh"
    echo "Pour voir les logs : docker compose logs -f"
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
main() {
    echo "=============================================="
    echo "Stack Universelle AI — Installation"
    echo "=============================================="
    echo ""

    verify_prereqs
    check_resources
    load_data_dir
    create_data_dirs
    generate_secrets
    start_stack
}

main "$@"
