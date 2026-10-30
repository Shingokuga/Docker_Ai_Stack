#!/usr/bin/env bash
# install.sh — Installation de la stack universelle AI
# Détecte la distro, installe les prérequis, configure les permissions,
# génère les secrets et lance la stack.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err() { echo "❌ $*" >&2; }

# -------------------------------------------------------
# a) Prérequis système (apt ou dnf)
# -------------------------------------------------------
install_deps() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        ID="${ID:-}"
    else
        err "Impossible de détecter la distribution (/etc/os-release manquant)"
        exit 1
    fi

    local PKG_MGR=""
    case "$ID" in
        ubuntu|debian) PKG_MGR="apt" ;;
        fedora|rhel) PKG_MGR="dnf" ;;
        *)
            err "Distribution non supportée : $ID"
            exit 1
            ;;
    esac

    if ! command -v sudo >/dev/null 2>&1; then
        warn "sudo non trouvé — tentative sans élévation (peut échouer)"
        sudo() { "$@"; }
    fi

    if [ "$PKG_MGR" = "apt" ]; then
        info "Installation via apt (Ubuntu/Debian)"
        sudo apt update -y
        sudo apt install -y git docker-compose-plugin curl wget ca-certificates jq
        sudo apt install -y git-lfs
    elif [ "$PKG_MGR" = "dnf" ]; then
        info "Installation via dnf (Fedora/RHEL)"
        sudo dnf -y install git docker-compose-plugin curl wget ca-certificates jq git-lfs
    fi

    # Docker Engine via dépôt officiel docker.com
    if ! command -v docker >/dev/null 2>&1; then
        info "Installation de Docker Engine (dépot officiel)"
        if [ "$PKG_MGR" = "apt" ]; then
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                -o /etc/apt/keyrings/docker.asc
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
                https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update -y
            sudo apt install -y docker-ce docker-ce-cli containerd.io
        elif [ "$PKG_MGR" = "dnf" ]; then
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf -y install docker-ce docker-ce-cli containerd.io
        fi
        sudo systemctl enable --now docker
    fi

    # Vérifier docker compose v2
    if ! docker compose version >/dev/null 2>&1; then
        warn "docker compose v2 non trouvé, installation du plugin"
        if [ "$PKG_MGR" = "apt" ]; then
            sudo apt install -y docker-compose-plugin
        else
            sudo dnf -y install docker-compose-plugin
        fi
    fi

    # git-lfs
    if ! command -v git-lfs >/dev/null 2>&1; then
        info "Installation de git-lfs"
        if [ "$PKG_MGR" = "apt" ]; then
            sudo apt install -y git-lfs
        else
            sudo dnf -y install git-lfs
        fi
    fi
    git lfs install
    ok "Prérequis système installés"
}

# -------------------------------------------------------
# b) GPU NVIDIA
# -------------------------------------------------------
configure_gpu() {
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        warn "nvidia-smi non trouvé — les services GPU (llama-server, docling, whisper, kokoro, ollama) ne démarreront pas"
        return 0
    fi

    info "GPU NVIDIA détecté"
    local driver_version
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    info "Pilote NVIDIA : $driver_version"

    # Vérifier version minimale (>= 570 pour cu128)
    if [ "${driver_version%%.*}" -lt 570 ]; then
        warn "Pilote NVIDIA < 570 — les modèles cu128 (docling, kokoro) peuvent échouer"
    fi

    # nvidia-container-toolkit
    if ! sudo docker info 2>/dev/null | grep -q nvidia; then
        info "Installation de nvidia-container-toolkit"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    local distro
                    distro=$(cat /etc/os-release | grep '^ID=' | cut -d= -f2)
                    local codename
                    codename=$(cat /etc/os-release | grep '^VERSION_CODENAME=' | cut -d= -f2)
                    if [ -z "$codename" ]; then
                        codename=$(lsb_release -cs 2>/dev/null || echo "bullseye")
                    fi
                    info "Ajout du dépôt NVIDIA (Ubuntu/Debian)"
                    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
                        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
                    curl -s -L https://nvidia.github.io/libnvidia-container/$distro/$codename/libnvidia-container.list \
                        | sed "s|deb https://|deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://|g" \
                        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
                    sudo apt update -y
                    sudo apt install -y nvidia-container-toolkit
                    ;;
                fedora|rhel)
                    sudo dnf -y install nvidia-container-toolkit
                    ;;
                *)
                    warn "Distribution non supportée pour nvidia-container-toolkit"
                    return 1
                    ;;
            esac
        fi
    fi

    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ok "GPU NVIDIA configuré"
}

# -------------------------------------------------------
# c) Vérification ressources
# -------------------------------------------------------
check_resources() {
    local mem_gb
    mem_gb=$(grep -P '^MemTotal:' /proc/meminfo | awk '{print int($2/1048576)}')
    info "RAM détectée : ${mem_gb} Go"
    if [ "$mem_gb" -lt 16 ]; then
        warn "RAM < 16 Go — la stack fonctionnera mais certaines tâches seront lentes"
    fi

    local disk_gb
    disk_gb=$(df -BG . | tail -n1 | awk '{print $4}' | tr -d 'G')
    info "Espace disque libre : ${disk_gb} Go"
    if [ "$disk_gb" -lt 100 ]; then
        warn "Espace disque < 100 Go — il faut au moins 100 Go pour les modèles et données"
    fi
    ok "Vérification des ressources terminée"
}

# -------------------------------------------------------
# d) Création des répertoires de données avec permissions
# -------------------------------------------------------
create_data_dirs() {
    info "Création des répertoires de données..."

    # Utilisateur du système (root si nécessaire)
    local run_as=""
    if [ "$(id -u)" -ne 0 ]; then
        run_as="sudo"
    fi

    # data dir de base
    $run_as mkdir -p data

    # postgres (999:999)
    $run_as mkdir -p data/postgres
    $run_as chown -R 999:999 data/postgres

    # redis (no root)
    $run_as mkdir -p data/redis

    # qdrant (no root)
    $run_as mkdir -p data/qdrant

    # ollama (no root)
    $run_as mkdir -p data/ollama

    # models (GGUF, no root)
    $run_as mkdir -p data/models

    # open-webui (no root)
    $run_as mkdir -p data/open-webui

    # n8n (1000:1000)
    $run_as mkdir -p data/n8n
    $run_as chown -R 1000:1000 data/n8n

    # n8n_shared (1000:1000)
    $run_as mkdir -p data/n8n_shared
    $run_as chown -R 1000:1000 data/n8n_shared

    # litellm (no root)
    $run_as mkdir -p data/litellm

    # caddy (no root)
    $run_as mkdir -p data/caddy

    # docling (no root)
    $run_as mkdir -p data/docling

    # kokoro (no root)
    $run_as mkdir -p data/kokoro

    # whisper (1000:1000)
    $run_as mkdir -p data/whisper
    $run_as chown -R 1000:1000 data/whisper

    # clickhouse (101:101)
    $run_as mkdir -p data/clickhouse/data
    $run_as chown -R 101:101 data/clickhouse/data
    $run_as mkdir -p data/clickhouse/logs
    $run_as chown -R 101:101 data/clickhouse/logs

    # s3 (10001:10001)
    $run_as mkdir -p data/s3
    $run_as chown -R 10001:10001 data/s3

    # langfuse (no root)
    $run_as mkdir -p data/langfuse

    # searxng (no root)
    $run_as mkdir -p data/searxng

    # portainer (no root)
    $run_as mkdir -p data/portainer

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
    docker compose --env-file versions.env --env-file .env pull

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
    echo "Pour voir les logs : ./stack logs -f"
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
main() {
    echo "=============================================="
    echo "Stack Universelle AI — Installation"
    echo "=============================================="
    echo ""

    install_deps
    configure_gpu
    check_resources
    create_data_dirs
    generate_secrets
    start_stack
}

main "$@"
