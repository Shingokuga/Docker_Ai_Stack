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
    local vram_mb=""

    # Essayer nvidia-smi avec nounits
    if command -v nvidia-smi >/dev/null 2>&1; then
        if vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '); then
            :
        else
            info "nvidia-smi a échoué — palier S par défaut"
            echo "S"
            return
        fi
    else
        info "nvidia-smi absent — palier S par défaut"
        echo "S"
        return
    fi

    # Vérifier si c'est un nombre valide
    if ! [ "$vram_mb" -gt 0 ] 2>/dev/null; then
        # Retirer les unités éventuelles (MiB)
        if [ -n "$vram_mb" ]; then
            vram_mb=$(echo "$vram_mb" | tr -d 'MiB' | tr -d ' ')
        fi
        if ! [ "$vram_mb" -gt 0 ] 2>/dev/null; then
            # Fallback sur /proc/meminfo
            if [ -f /proc/meminfo ]; then
                local mem_kb
                mem_kb=$(/usr/bin/grep -m1 '^MemTotal:' /proc/meminfo | /usr/bin/awk '{print $2}')
                if [ -n "$mem_kb" ]; then
                    vram_mb=$(( mem_kb / 1024 ))
                    info "Mémoire système détectée : ${vram_mb} MB"
                fi
            fi
        fi
    else
        info "VRAM détectée : ${vram_mb} MB"
    fi

    # Si toujours pas de valeur, palier S
    if ! [ "$vram_mb" -gt 0 ] 2>/dev/null; then
        info "Impossible de détecter la mémoire — palier S par défaut"
        echo "S"
        return
    fi

    # Paliers : L ≥ 24 Go, M ≥ 8 Go, sinon S
    if [ "$vram_mb" -ge 24576 ]; then
        info "Palier GPU détecté : L (≥24 Go)"
        echo "L"
    elif [ "$vram_mb" -ge 8192 ]; then
        info "Palier GPU détecté : M (8 à 24 Go)"
        echo "M"
    else
        info "Palier GPU détecté : S (<8 Go)"
        echo "S"
    fi
}

# -------------------------------------------------------
# Helpers: read/write .env safely (no sed, no string concat)
# -------------------------------------------------------
get_env() {
    local key="$1"
    local val=""
    if [ -f .env ]; then
        val=$(/usr/bin/grep -m1 "^${key}=" .env 2>/dev/null | /usr/bin/cut -d'=' -f2-)
    fi
    echo "$val"
}

set_env() {
    local key="$1"
    local value="$2"
    # Pass value via environment variable to avoid shell injection
    ENV_SET_KEY="$key" ENV_SET_VALUE="$value" python3 -c '
import os
key = os.environ["ENV_SET_KEY"]
value = os.environ["ENV_SET_VALUE"]
path = ".env"
lines = []
found = False
if os.path.exists(path):
    with open(path, "r") as f:
        for line in f:
            if line.startswith(key + "="):
                lines.append(f"{key}={value}\n")
                found = True
            else:
                lines.append(line)
if not found:
    lines.append(f"{key}={value}\n")
with open(path, "w") as f:
    f.writelines(lines)
'
}

# -------------------------------------------------------
# c) Questions interactives ou mode --yes
# -------------------------------------------------------
get_env() {
    local key="$1"
    if [ -f .env ]; then
        /usr/bin/grep -m1 "^${key}=" .env 2>/dev/null | /usr/bin/cut -d'=' -f2-
    fi
}

set_env() {
    local key="$1"
    local value="$2"
    # Pass value via env var to avoid shell injection in sed/awk
    ENV_SET_KEY="$key" ENV_SET_VALUE="$value" python3 -c '
import os
key = os.environ["ENV_SET_KEY"]
value = os.environ["ENV_SET_VALUE"]
path = ".env"
lines = []
found = False
if os.path.exists(path):
    with open(path, "r") as f:
        for line in f:
            if line.startswith(key + "="):
                lines.append(f"{key}={value}\n")
                found = True
            else:
                lines.append(line)
if not found:
    lines.append(f"{key}={value}\n")
with open(path, "w") as f:
    f.writelines(lines)
'
}

ask_config() {
    info "Configuration de la stack..."

    # Domaine
    local env_base_domain
    env_base_domain=$(get_env BASE_DOMAIN)
    if [ $YES_MODE -eq 1 ]; then
        BASE_DOMAIN="${BASE_DOMAIN:-${env_base_domain:-local}}"
    else
        local domain_hint="${env_base_domain:-local}"
        info "Entrez le domaine de base (ex: exemple.com) ou 'local' pour http://localhost :"
        read -r -e -p "Domaine (${domain_hint}) : " -i "$domain_hint" BASE_DOMAIN
    fi

    # Email admin
    local env_admin_email
    env_admin_email=$(get_env WEBUI_ADMIN_EMAIL)
    if [ $YES_MODE -eq 1 ]; then
        ADMIN_EMAIL="${ADMIN_EMAIL:-${env_admin_email:-admin@${BASE_DOMAIN}}}"
    else
        local email_hint="${env_admin_email:-admin@${BASE_DOMAIN}}"
        info "Entrez l'email de l'administrateur pour Open WebUI et Langfuse :"
        read -r -e -p "Email admin (${email_hint}) : " -i "$email_hint" ADMIN_EMAIL
    fi

    # ComfyUI
    local env_compose_profiles
    env_compose_profiles=$(get_env COMPOSE_PROFILES)
    local comfyui_hint="non"
    if [ "$env_compose_profiles" = "comfyui" ]; then
        comfyui_hint="oui"
    fi
    if [ $YES_MODE -eq 1 ]; then
        if [ "${ENABLE_COMFYUI:-}" = "1" ] || [ "${ENABLE_COMFYUI:-}" = "true" ]; then
            COMFYUI_ENABLED=1
        elif [ "${ENABLE_COMFYUI:-}" = "0" ] || [ "${ENABLE_COMFYUI:-}" = "false" ]; then
            COMFYUI_ENABLED=0
        else
            if [ "$env_compose_profiles" = "comfyui" ]; then
                COMFYUI_ENABLED=1
            else
                COMFYUI_ENABLED=0
            fi
        fi
    else
        info "Installer ComfyUI ? (~41 Go de modèles supplémentaires)"
        read -r -e -p "ComfyUI (${comfyui_hint}) : " COMFYUI_ENABLED
        if [ "$COMFYUI_ENABLED" = "yes" ] || [ "$COMFYUI_ENABLED" = "1" ] || [ "$COMFYUI_ENABLED" = "true" ] || [ "$COMFYUI_ENABLED" = "oui" ]; then
            COMFYUI_ENABLED=1
        else
            COMFYUI_ENABLED=0
        fi
    fi

    # GPU Tier
    local env_gpu_tier
    env_gpu_tier=$(get_env GPU_TIER)
    if [ $YES_MODE -eq 1 ]; then
        if [ -n "${GPU_TIER:-}" ]; then
            : # Use env var
        elif [ -n "$env_gpu_tier" ]; then
            GPU_TIER="$env_gpu_tier"
        else
            GPU_TIER=$(detect_gpu_tier)
        fi
    else
        local detected
        if [ -n "$env_gpu_tier" ]; then
            detected="$env_gpu_tier"
        else
            detected=$(detect_gpu_tier)
        fi
        info "Palier GPU détecté : $detected"
        read -r -e -p "Palier GPU (M/S/L) — S=<8Go, M=8-24Go, L=≥24Go : " -i "$detected" GPU_TIER
        GPU_TIER=$(echo "$GPU_TIER" | tr '[:lower:]' '[:upper:]')
    fi
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
    set_env BASE_DOMAIN "$BASE_DOMAIN"
    set_env WEBUI_ADMIN_EMAIL "$ADMIN_EMAIL"
    set_env LANGFUSE_INIT_USER_EMAIL "$ADMIN_EMAIL"
    set_env GPU_TIER "$GPU_TIER"
    if [ "$COMFYUI_ENABLED" -eq 1 ]; then
        set_env COMPOSE_PROFILES "comfyui"
    else
        set_env COMPOSE_PROFILES ""
    fi
    COMPOSE_PROFILES=$(get_env COMPOSE_PROFILES)

    # Sélection des modèles via download-models.sh --select-only
    info "Sélection des modèles selon GPU_TIER=$GPU_TIER..."
    if ! bash download-models.sh --select-only; then
        err "Sélection des modèles échouée (download-models.sh --select-only)."
        exit 1
    fi

    # Lire les modèles sélectionnés dans .env
    LLM_GGUF=$(/usr/bin/grep -m1 '^LLM_GGUF=' .env | /usr/bin/cut -d'=' -f2-)
    LLM_MMPROJ=$(/usr/bin/grep -m1 '^LLM_MMPROJ=' .env | /usr/bin/cut -d'=' -f2-)

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
    echo "Modèle vision : $LLM_MMPROJ"
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