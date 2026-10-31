#!/usr/bin/env bash
# bootstrap.sh — Point d'entrée unique pour installer la stack universelle AI
# Prérequis système, installation Docker/GPU, clonage du dépôt, puis installation.
#
# Usage pour un dépôt privé (GitHub) :
#   1. Créez un jeton fine-grained en lecture seule :
#        GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
#        Repository access : Only select repositories → Docker_Ai_Stack
#        Permissions : Contents → Read-only
#        Expiration : 7 jours (ou à votre convenance)
#   2. Exportez le jeton :
#        export GITHUB_TOKEN=github_pat_xxxxxxxx
#   3. Téléchargez ce script :
#        curl -fsSL -H "Authorization: Bearer ***" \
#             https://raw.githubusercontent.com/Shingokuga/Docker_Ai_Stack/main/bootstrap.sh \
#             -o bootstrap.sh
#   4. Exécutez-le :
#        bash bootstrap.sh
#   (Note : la ligne de téléchargement n'a pas encore été testée avec un vrai jeton.)
#
# Options :
#   GITHUB_TOKEN   Jeton d'accès pour un dépôt GitHub privé.
#   STACK_BRANCH   Branche à cloner (défaut : main). Ex. : dev.
#   STACK_REPO_URL URL du dépôt (défaut : Shingokuga/Docker_Ai_Stack).
#   STACK_DIR      Répertoire de destination (défaut : $HOME/Docker_Ai_Stack).
#   BOOTSTRAP_YES  Si "1", ne demande pas de confirmation.
set -euo pipefail

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err() { echo "❌ $*" >&2; }

# -------------------------------------------------------
# Fonction d'authentification git pour dépôts privés
# Utilise une variable d'environnement pour l'en-tête — le jeton
# n'est jamais écrit dans l'URL, un argument de commande ou un fichier.
# -------------------------------------------------------
git_auth() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        GIT_CONFIG_COUNT=1 \
        GIT_CONFIG_KEY_0=http.extraHeader \
        GIT_CONFIG_VALUE_0="Authorization: Basic $(echo -n "x-access-token:${GITHUB_TOKEN}" | base64 -w0)" \
        git "$@"
    else
        git "$@"
    fi
}

# -------------------------------------------------------
# Configuration
# -------------------------------------------------------
STACK_REPO_URL="${STACK_REPO_URL:-https://github.com/Shingokuga/Docker_Ai_Stack.git}"
STACK_BRANCH="${STACK_BRANCH:-main}"
STACK_DIR="${STACK_DIR:-$HOME/Docker_Ai_Stack}"

info "Dépôt : $STACK_REPO_URL (branche : $STACK_BRANCH)"
info "Répertoire cible : $STACK_DIR"

# -------------------------------------------------------
# Détection de l'utilisateur root vs sudo
# -------------------------------------------------------
if [ "$(id -u)" = "0" ]; then
    SUDO=""
else
    if ! command -v sudo >/dev/null 2>&1; then
        err "Script non exécuté en root et 'sudo' non trouvé. Impossible de continuer."
        exit 1
    fi
    SUDO="sudo"
fi

# -------------------------------------------------------
# Détection de la distribution (Ubuntu 22.04 / 24.04)
# -------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    ID="${ID:-}"
    VERSION_ID="${VERSION_ID:-}"
else
    err "Impossible de détecter la distribution (/etc/os-release manquant)"
    exit 1
fi

if [ "$ID" = "ubuntu" ]; then
    if [ "$VERSION_ID" != "22.04" ] && [ "$VERSION_ID" != "24.04" ]; then
        warn "Ubuntu $VERSION_ID détecté (versions supportées : 22.04 ou 24.04)"
        if [ "${BOOTSTRAP_YES:-}" != "1" ]; then
            read -r -p "Continuer quand même ? [o/N] " REPLY < /dev/tty
            case "$REPLY" in
                [oO]*) ;;
                *) info "Abandon."; exit 1 ;;
            esac
        fi
    fi
else
    err "Distribution non supportée : $ID (attendu : Ubuntu)"
    exit 1
fi

info "Distribution détectée : $ID $VERSION_ID"

# -------------------------------------------------------
# Mise à jour système complète
# -------------------------------------------------------
info "Mise à jour système complète (apt update && apt upgrade)..."
export DEBIAN_FRONTEND=noninteractive
$SUDO apt update -y
$SUDO apt upgrade -y -o Dpkg::Options::="--force-confold"

# Vérifier si redémarrage nécessaire
if [ -f /var/run/reboot-required ]; then
    ok "Mise à jour terminée"
    echo ""
    echo "⚠️  Un redémarrage est nécessaire après la mise à jour du noyau."
    echo "Redémarrez la machine, puis relancez cette même commande :"
    echo "  curl -fsSL -H \"Authorization: Bearer \$GITHUB_TOKEN\" https://raw.githubusercontent.com/Shingokuga/Docker_Ai_Stack/${STACK_BRANCH}/bootstrap.sh -o bootstrap.sh && bash bootstrap.sh"
    exit 0
fi
ok "Système à jour"

# -------------------------------------------------------
# Paquets de base
# -------------------------------------------------------
info "Installation des paquets de base (git, curl, ca-certificates, jq, git-lfs)..."
$SUDO apt install -y git git-lfs curl ca-certificates jq
ok "Paquets de base installés"

# -------------------------------------------------------
# Docker via dépôt officiel
# -------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker et docker compose v2 déjà installés"
else
    info "Installation de Docker via le dépôt officiel docker.com..."
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    $SUDO apt update -y
    $SUDO apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    $SUDO systemctl enable --now docker
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
        $SUDO curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
            | $SUDO gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        $SUDO curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
            | $SUDO sed "s|deb https://|deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://|g" \
            | $SUDO tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        $SUDO apt update -y
        $SUDO apt install -y nvidia-container-toolkit
    fi

    if ! docker info --format '{{json .Runtimes}}' | grep -q '"nvidia"'; then
        info "Configuration du runtime NVIDIA pour Docker"
        $SUDO nvidia-ctk runtime configure --runtime=docker
        $SUDO systemctl restart docker
        ok "Runtime NVIDIA configuré et Docker redémarré"
    else
        info "Runtime NVIDIA déjà configuré — pas de redémarrage de Docker"
    fi
    ok "GPU NVIDIA configuré"
else
    warn "nvidia-smi non trouvé — les services GPU ne démarreront pas"
fi

# -------------------------------------------------------
# Permissions Docker
# -------------------------------------------------------
if ! groups | grep -q docker; then
    DOCKER_USER="${SUDO_USER:-${USER:-}}"
    if [ -z "$DOCKER_USER" ]; then
        DOCKER_USER=$(id -un)
    fi
    if [ "$DOCKER_USER" = "root" ]; then
        info "Utilisateur root — pas besoin de l'ajouter au groupe docker"
    else
        info "Ajout de $DOCKER_USER au groupe docker"
        $SUDO usermod -aG docker "$DOCKER_USER"
        warn "Le groupe docker sera actif à la prochaine connexion pour $DOCKER_USER"
    fi
fi
ok "Groupe docker configuré"

# -------------------------------------------------------
# git lfs
# -------------------------------------------------------
if ! command -v git-lfs >/dev/null 2>&1; then
    $SUDO apt install -y git-lfs
fi
git lfs install
ok "git-lfs installé"

# -------------------------------------------------------
# Clone / Pull du dépôt (support dépôt privé via variable env)
# -------------------------------------------------------
if [ -d "$STACK_DIR" ]; then
    info "Répertoire $STACK_DIR existe — mise à jour sur la branche $STACK_BRANCH..."
    cd "$STACK_DIR"
    git_auth fetch origin "$STACK_BRANCH"
    git checkout "$STACK_BRANCH"
    git_auth pull --ff-only origin "$STACK_BRANCH"
else
    info "Clonage de $STACK_REPO_URL (branche : $STACK_BRANCH) vers $STACK_DIR..."
    mkdir -p "$(dirname "$STACK_DIR")"

    if ! git_auth clone --branch "$STACK_BRANCH" "$STACK_REPO_URL" "$STACK_DIR" 2>/dev/null; then
        if [ -z "${GITHUB_TOKEN:-}" ]; then
            err "Clonage du dépôt échoué."
            echo ""
            echo "Si le dépôt est privé, définissez GITHUB_TOKEN :"
            echo "  GITHUB_TOKEN=votre-jeton ./bootstrap.sh"
            echo ""
            echo "Pour créer un token : https://github.com/settings/tokens/new"
            echo "(scope : repo)"
            exit 1
        else
            err "Clonage du dépôt privé échoué (GITHUB_TOKEN défini)."
            exit 1
        fi
    fi
fi
cd "$STACK_DIR"
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
