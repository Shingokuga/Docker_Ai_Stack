#!/usr/bin/env bash
# install.sh — Installation de la stack universelle AI
# Point d'entrée unique pour installer la stack : prérequis, configuration, secrets, téléchargement des modèles, démarrage.
# Les paquets système et Docker doivent déjà être installés (voir bootstrap.sh).
#
# Options :
#   --yes          Mode sans interaction (utilise les variables d'environnement BASE_DOMAIN, ADMIN_EMAIL, ENABLE_COMFYUI, GPU_TIER)
#   --config-only  S'arrête après la validation de la configuration (ne télécharge, ne crée et ne lance rien d'autre)
info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
err() { echo "❌ $*" >&2; }

YES_MODE=0
CONFIG_ONLY=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --yes) YES_MODE=1 ;;
            --config-only) CONFIG_ONLY=1 ;;
        esac
    done
}

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
# b) Détection du palier GPU
# -------------------------------------------------------
detect_gpu_tier() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        # Vérifier la VRAM
        local vram_mb
        vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ')
        if [ -n "$vram_mb" ] && [ "$vram_mb" -gt 0 ]; then
            info "VRAM détectée : ${vram_mb} MB"
            if [ "$vram_mb" -ge 16384 ]; then
                info "Palier GPU détecté : L (≥16 Go VRAM)"
                return "L"
            else
                info "Palier GPU détecté : M (<16 Go VRAM)"
                return "M"
            fi
        else
            info "Impossible de détecter la VRAM — palier M par défaut"
        fi
    else
        info "Aucun GPU détecté — palier M par défaut"
    fi
    return "M"
}

# -------------------------------------------------------
# c) Questions interactives ou mode --yes
# -------------------------------------------------------
ask_config() {
    info "Configuration de la stack..."

    # Domaine
    if [ $YES_MODE -eq 1 ]; then
        BASE_DOMAIN="${BASE_DOMAIN:-local}"
    else
        info "Entrez le domaine de base (ex: exemple.com) ou 'local' pour http://localhost :"
        read -r -e -p "Domaine (local) : " -i "local" BASE_DOMAIN
    fi

    # Email admin
    if [ $YES_MODE -eq 1 ]; then
        ADMIN_EMAIL="${ADMIN_EMAIL:-admin@${BASE_DOMAIN}}"
    else
        info "Entrez l'email de l'administrateur pour Open WebUI et Langfuse :"
        read -r -e -p "Email admin (admin@${BASE_DOMAIN}) : " -i "admin@${BASE_DOMAIN}" ADMIN_EMAIL
    fi

    # ComfyUI
    if [ $YES_MODE -eq 1 ]; then
        COMFYUI_ENABLED="${ENABLE_COMFYUI:-0}"
        if [ "$COMFYUI_ENABLED" = "1" ] || [ "$COMFYUI_ENABLED" = "true" ]; then
            COMFYUI_ENABLED=1
        else
            COMFYUI_ENABLED=0
        fi
    else
        info "Installer ComfyUI ? (~41 Go de modèles supplémentaires)"
        read -r -e -p "ComfyUI (non) : " COMFYUI_ENABLED
        if [ "$COMFYUI_ENABLED" = "yes" ] || [ "$COMFYUI_ENABLED" = "1" ] || [ "$COMFYUI_ENABLED" = "true" ]; then
            COMFYUI_ENABLED=1
        else
            COMFYUI_ENABLED=0
        fi
    fi

    # GPU Tier
    if [ $YES_MODE -eq 1 ]; then
        GPU_TIER="${GPU_TIER:-M}"
    else
        local detected
        detect_gpu_tier
        detected=$?
        if [ "$detected" -eq 0 ]; then
            detected="L"
        else
            detected="M"
        fi
        info "Palier GPU détecté : $detected"
        read -r -e -p "Palier GPU (M/S/L) — S=<8Go, M=8-16Go, L=≥16Go : " -i "$detected" GPU_TIER
        GPU_TIER=$(echo "$GPU_TIER" | tr '[:lower:]' '[:upper:]')
    fi

    # Choix du modèle LLM selon le palier GPU
    case "$GPU_TIER" in
        L)
            LLM_GGUF="Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-Q4_K_M.gguf"
            ;;
        *)
            LLM_GGUF="Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-Q4_K_M.gguf"
            ;;
    esac

    info "Modèle LLM sélectionné : $LLM_GGUF"
}

# -------------------------------------------------------
# d) Création de .env et génération des secrets
# -------------------------------------------------------
create_env() {
    if [ -f .env ]; then
        info ".env existe déjà — mise à jour de la configuration..."
    else
        info "Copie de .env.example vers .env"
        cp .env.example .env
    fi

    # Écrire les réponses dans .env de manière sécurisée
    sed -i "s|^BASE_DOMAIN=.*|BASE_DOMAIN=${BASE_DOMAIN}|" .env
    sed -i "s|^WEBUI_ADMIN_EMAIL=.*|WEBUI_ADMIN_EMAIL=${ADMIN_EMAIL}|" .env
    sed -i "s|^LANGFUSE_INIT_USER_EMAIL=.*|LANGFUSE_INIT_USER_EMAIL=${ADMIN_EMAIL}|" .env
    sed -i "s|^GPU_TIER=.*|GPU_TIER=${GPU_TIER}|" .env
    sed -i "s|^LLM_GGUF=.*|LLM_GGUF=${LLM_GGUF}|" .env

    if [ "$COMFYUI_ENABLED" -eq 1 ]; then
        COMPOSE_PROFILES="comfyui"
    else
        COMPOSE_PROFILES=""
    fi
    sed -i "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=${COMPOSE_PROFILES}|" .env

    # Générer les secrets si nécessaire
    if [ -f scripts/gen-secrets.sh ]; then
        info "Génération des secrets..."
        bash scripts/gen-secrets.sh
        ok "Secrets générés"
    else
        warn "scripts/gen-secrets.sh manquant — secrets non générés"
    fi

    # Récapitulatif
    echo ""
    echo "=============================================="
    echo "Récapitulatif de configuration"
    echo "=============================================="
    echo "Domaine : $BASE_DOMAIN"
    echo "Email admin : $ADMIN_EMAIL"
    echo "Palier GPU : $GPU_TIER"
    echo "Modèle LLM : $LLM_GGUF"
    echo "ComfyUI : $([ "$COMFYUI_ENABLED" -eq 1 ] && echo "activé" || echo "désactivé")"
    echo "COMPOSE_PROFILES : $COMPOSE_PROFILES"
    echo "=============================================="
    echo ""

    if [ $YES_MODE -eq 0 ]; then
        read -r -p "Confirmez-vous cette configuration ? (o/n) : " confirm
        case "$confirm" in
            [oO]|yes|Yes|YES) ;;
            *)
                err "Installation annulée par l'utilisateur."
                exit 1
                ;;
        esac
    fi
}

# -------------------------------------------------------
# e) Validation de la configuration
# -------------------------------------------------------
validate_config() {
    info "Validation de la configuration..."

    # Vérifier que les variables obligatoires ne sont pas vides
    local missing=0
    if [ -z "$BASE_DOMAIN" ]; then missing=1; fi
    if [ -z "$ADMIN_EMAIL" ]; then missing=1; fi
    if [ -z "$GPU_TIER" ]; then missing=1; fi
    if [ -z "$LLM_GGUF" ]; then missing=1; fi

    if [ $missing -eq 1 ]; then
        err "Une ou plusieurs variables obligatoires sont vides."
        exit 1
    fi

    # Vérifier la syntaxe du compose
    if ! docker compose --env-file versions.env --env-file .env config -q; then
        err "La configuration compose est invalide. Vérifiez les variables d'environnement."
        exit 1
    fi
    ok "Configuration valide"
    return 0
}

# -------------------------------------------------------
# f) Téléchargement des modèles
# -------------------------------------------------------
download_models() {
    if [ -f download-models.sh ]; then
        info "Téléchargement des modèles..."
        if ! bash download-models.sh; then
            err "Téléchargement des modèles échoué. Vérifiez que tous les fichiers sont présents."
            exit 1
        fi
        ok "Modèles téléchargés"
    else
        warn "download-models.sh manquant — téléchargement des modèles ignoré"
    fi
}

# -------------------------------------------------------
# g) Création des répertoires de données
# -------------------------------------------------------
create_data_dirs() {
    info "Création des répertoires de données..."

    local run_as=""
    if [ "$(id -u)" -ne 0 ]; then
        run_as="sudo"
    fi

    local DATA_DIR="./data"

    $run_as mkdir -p "$DATA_DIR"
    $run_as mkdir -p "$DATA_DIR/postgres"
    $run_as chown -R 999:999 "$DATA_DIR/postgres"
    $run_as mkdir -p "$DATA_DIR/redis"
    $run_as mkdir -p "$DATA_DIR/qdrant"
    $run_as mkdir -p "$DATA_DIR/ollama"
    $run_as mkdir -p "$DATA_DIR/models"
    $run_as mkdir -p "$DATA_DIR/open-webui"
    $run_as mkdir -p "$DATA_DIR/n8n"
    $run_as chown -R 1000:1000 "$DATA_DIR/n8n"
    $run_as mkdir -p "$DATA_DIR/n8n_shared"
    $run_as chown -R 1000:1000 "$DATA_DIR/n8n_shared"
    $run_as mkdir -p "$DATA_DIR/portainer"
    $run_as mkdir -p "$DATA_DIR/caddy"
    $run_as mkdir -p "$DATA_DIR/whisper"
    $run_as chown -R 1000:1000 "$DATA_DIR/whisper"
    $run_as mkdir -p "$DATA_DIR/clickhouse/data"
    $run_as chown -R 101:101 "$DATA_DIR/clickhouse/data"
    $run_as mkdir -p "$DATA_DIR/clickhouse/logs"
    $run_as chown -R 101:101 "$DATA_DIR/clickhouse/logs"
    $run_as mkdir -p "$DATA_DIR/s3"
    $run_as chown -R 10001:10001 "$DATA_DIR/s3"
    ok "Répertoires de données créés"
}

# -------------------------------------------------------
# h) Pull et démarrage de la stack
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
}

# -------------------------------------------------------
# i) Configuration de Open WebUI
# -------------------------------------------------------
configure_webui() {
    if [ -f scripts/configure-openwebui.sh ]; then
        info "Configuration de Open WebUI (compte admin + outils MCP)..."
        bash scripts/configure-openwebui.sh
        ok "Open WebUI configuré"
    else
        warn "scripts/configure-openwebui.sh manquant — configuration WebUI ignorée"
    fi
}

# -------------------------------------------------------
# j) Récapitulatif final
# -------------------------------------------------------
final_summary() {
    echo ""
    echo "=============================================="
    echo "Installation terminée !"
    echo "=============================================="
    echo ""
    echo "🌐 URLs de la stack (https) :"
    echo "  Chat AI : https://chat-ai.${BASE_DOMAIN}"
    echo "  n8n Automation : https://automatisation.${BASE_DOMAIN}"
    echo "  Langfuse Monitoring : https://suivi-ia.${BASE_DOMAIN}"
    echo "  Portainer Admin : https://admin.${BASE_DOMAIN}"
    echo "  API : https://api.${BASE_DOMAIN}"
    echo "  Documents : https://documents.${BASE_DOMAIN}"
    echo "  Stockage S3 : https://stockage.${BASE_DOMAIN}"
    echo ""
    echo "Pour trouver le mot de passe admin : vérifiez le fichier .env"
    echo "Pour vérifier la stack : ./test-stack.sh"
    echo "Pour voir les logs : docker compose logs -f"
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
main() {
    parse_args "$@"
    set -euo pipefail
    cd "$REPO_ROOT"

    echo "=============================================="
    echo "Stack Universelle AI — Installation"
    echo "=============================================="
    echo ""

    verify_prereqs
    ask_config
    create_env
    validate_config

    if [ $CONFIG_ONLY -eq 1 ]; then
        ok "Mode --config-only : arrêt après validation"
        return 0
    fi

    download_models
    create_data_dirs
    start_stack
    configure_webui
    final_summary
}

if [ "${BASH_SOURCE}" = "$0" ]; then
    main "$@"
fi