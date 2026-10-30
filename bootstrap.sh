#!/usr/bin/env bash
# bootstrap.sh — Prérequis système pour la stack universelle AI
# Copier ce script seul sur une machine vierge et le lancer.
# Installe Docker, git, les dépendances nécessaires, configure le GPU,
# clone le dépôt et prépare le lancement de install.sh.
set -euo pipefail

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err() { echo "❌ $*" >&2; }

# -------------------------------------------------------
# Configuration
# -------------------------------------------------------
STACK_REPO_URL="${STACK_REPO_URL:-${1:-}}"
STACK_DIR="${STACK_DIR:-$HOME/stack}"

if [ -z "$STACK_REPO_URL" ]; then
    err "STACK_REPO_URL non défini."
    echo "Utilisation : STACK_REPO_URL=https://github.com/.../repo.git ./bootstrap.sh"
    echo "   ou : ./bootstrap.sh https://github.com/.../repo.git"
    exit 1
fi

info "Dépôt : $STACK_REPO_URL"
info "Répertoire cible : $STACK_DIR"

# -------------------------------------------------------
# Détection de la distribution
# -------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    ID="${ID:-}"
else
    err "Impossible de détecter la distribution (/etc/os-release manquant)"
    exit 1
fi

PKG_MGR=""
case "$ID" in
    ubuntu|debian) PKG_MGR="apt" ;;
    fedora|rhel) PKG_MGR="dnf" ;;
    *)
        err "Distribution non supportée : $ID"
        exit 1
        ;;
esac

info "Distribution détectée : $ID (via $PKG_MGR)"

# sudo helper
if ! command -v sudo >/dev/null 2>&1; then
    warn "sudo non trouvé — tentative sans élévation"
    sudo() { "$@"; }
fi

# -------------------------------------------------------
# Paquets de base
# -------------------------------------------------------
info "Installation des paquets de base (git, curl, ca-certificates, jq, git-lfs)..."
if [ "$PKG_MGR" = "apt" ]; then
    sudo apt update -y
    sudo apt install -y git git-lfs curl ca-certificates jq
elif [ "$PKG_MGR" = "dnf" ]; then
    sudo dnf -y install git git-lfs curl ca-certificates jq
fi
ok "Paquets de base installés"

# -------------------------------------------------------
# Docker via dépôt officiel
# -------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker et docker compose v2 déjà installés"
else
    info "Installation de Docker via le dépôt officiel docker.com..."
    if [ "$PKG_MGR" = "apt" ]; then
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update -y
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [ "$PKG_MGR" = "dnf" ]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    sudo systemctl enable --now docker
    ok "Docker installé et démarré"
fi

# -------------------------------------------------------
# GPU NVIDIA
# -------------------------------------------------------
if command -v nvidia-smi >/dev/null 2>&1; then
    info "GPU NVIDIA détecté"
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    info "Pilote NVIDIA : $driver_version"

    if [ "${driver_version%%.*}" -lt 570 ]; then
        warn "Pilote NVIDIA < 570 — les modèles cu128 (docling, kokoro) peuvent échouer"
    fi

    if ! docker info 2>/dev/null | grep -q nvidia; then
        info "Installation de nvidia-container-toolkit"
        if [ "$PKG_MGR" = "apt" ]; then
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
                | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
            curl -s -L https://nvidia.github.io/libnvidia-container/$ID/$(cat /etc/os-release | grep '^VERSION_CODENAME=' | cut -d= -f2)/libnvidia-container.list \
                | sed "s|deb https://|deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://|g" \
                | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
            sudo apt update -y
            sudo apt install -y nvidia-container-toolkit
        elif [ "$PKG_MGR" = "dnf" ]; then
            sudo dnf -y install nvidia-container-toolkit
        fi
    fi

    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ok "GPU NVIDIA configuré"
else
    warn "nvidia-smi non trouvé — les services GPU ne démarreront pas"
fi

# -------------------------------------------------------
# Permissions Docker
# -------------------------------------------------------
if ! groups | grep -q docker; then
    info "Ajout de $USER au groupe docker"
    sudo usermod -aG docker "$USER"
    warn "Ouvrez une nouvelle session pour que le groupe docker s'applique"
fi
ok "Groupe docker configuré"

# -------------------------------------------------------
# git lfs
# -------------------------------------------------------
if ! command -v git-lfs >/dev/null 2>&1; then
    if [ "$PKG_MGR" = "apt" ]; then
        sudo apt install -y git-lfs
    else
        sudo dnf -y install git-lfs
    fi
fi
git lfs install
ok "git-lfs installé"

# -------------------------------------------------------
# Clone / Pull du dépôt
# -------------------------------------------------------
if [ -d "$STACK_DIR" ]; then
    info "Répertoire $STACK_DIR existe — mise à jour..."
    cd "$STACK_DIR"
    git pull
else
    info "Clonage de $STACK_REPO_URL vers $STACK_DIR..."
    mkdir -p "$(dirname "$STACK_DIR")"
    git clone "$STACK_REPO_URL" "$STACK_DIR"
    cd "$STACK_DIR"
fi
git lfs pull
ok "Dépôt prêt à $STACK_DIR"

echo ""
echo "=============================================="
echo "Bootstrap terminé !"
echo "=============================================="
echo ""
echo "Ouvre une nouvelle session (groupe docker) puis lance :"
echo "  cd $STACK_DIR && ./install.sh"
echo ""
