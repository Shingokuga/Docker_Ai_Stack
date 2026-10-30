#!/usr/bin/env bash
# bootstrap.sh — Point d'entrée unique pour installer la stack universelle AI
# Prérequis système, installation Docker/GPU, clonage du dépôt, puis installation.
# Compatible "curl | bash" — utilise /dev/tty pour les questions si nécessaire.
set -euo pipefail

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err() { echo "❌ $*" >&2; }

# -------------------------------------------------------
# Configuration
# -------------------------------------------------------
STACK_REPO_URL="${STACK_REPO_URL:-https://github.com/Shingokuga/Docker_Ai_Stack.git}"
STACK_DIR="${STACK_DIR:-$HOME/Docker_Ai_Stack}"

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
# Mise à jour système complète
# -------------------------------------------------------
info "Mise à jour système complète (apt update && apt upgrade)..."
if [ "$PKG_MGR" = "apt" ]; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt update -y
    sudo apt upgrade -y -o Dpkg::Options::="--force-confold"
elif [ "$PKG_MGR" = "dnf" ]; then
    sudo dnf -y upgrade
fi

# Vérifier si redémarrage nécessaire
if [ -f /var/run/reboot-required ]; then
    ok "Mise à jour terminée"
    echo ""
    echo "⚠️  Un redémarrage est nécessaire après la mise à jour du noyau."
    echo "Redémarrez la machine, puis relancez cette même commande :"
    echo "  $0"
    exit 0
fi
ok "Système à jour"

# -------------------------------------------------------
# Paquets de base
# -------------------------------------------------------
info "Installation des paquets de base (git, curl, ca-certificates, jq, git-lfs)..."
if [ "$PKG_MGR" = "apt" ]; then
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
    warn "Le groupe docker sera actif à la prochaine connexion"
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
# Clone / Pull du dépôt (avec support dépôt privé)
# -------------------------------------------------------
if [ -d "$STACK_DIR" ]; then
    info "Répertoire $STACK_DIR existe — mise à jour..."
    cd "$STACK_DIR"
    git pull
else
    info "Clonage de $STACK_REPO_URL vers $STACK_DIR..."
    mkdir -p "$(dirname "$STACK_DIR")"

    if [ -n "${GITHUB_TOKEN:-}" ]; then
        # Dépôt privé : utiliser le jeton pour l'authentification
        CLONE_URL=$(echo "$STACK_REPO_URL" | sed 's|https://github.com/|https://oauth2:'"$GITHUB_TOKEN"'@github.com/|')
        git clone "$CLONE_URL" "$STACK_DIR"
        # Ne pas laisser le jeton dans .git/config
        cd "$STACK_DIR"
        git remote set-url origin "$STACK_REPO_URL"
        cd -
    else
        if ! git clone "$STACK_REPO_URL" "$STACK_DIR" 2>/dev/null; then
            err "Clonage du dépôt échoué."
            echo ""
            echo "Si le dépôt est privé, définissez GITHUB_TOKEN :"
            echo "  GITHUB_TOKEN=votre-jeton ./bootstrap.sh"
            echo ""
            echo "Pour créer un token : https://github.com/settings/tokens/new"
            echo "(scope : repo)"
            exit 1
        fi
    fi
fi
cd "$STACK_DIR"
git lfs pull
ok "Dépôt prêt à $STACK_DIR"

# -------------------------------------------------------
# Lancement automatique de install.sh
# -------------------------------------------------------
echo ""
echo "=============================================="
echo "Bootstrap terminé ! Lancement de l'installation..."
echo "=============================================="
echo ""

# Si on n'est pas dans le groupe docker, on utilise sg pour éviter le problème
if groups | grep -q docker; then
    bash "$STACK_DIR/install.sh"
else
    sg docker -c "bash $STACK_DIR/install.sh"
fi