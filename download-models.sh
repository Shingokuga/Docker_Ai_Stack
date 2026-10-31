#!/usr/bin/env bash
# download-models.sh — Télécharge les modèles pour la stack universelle
# Utilise .env pour les paramètres. Ne télécharge pas les images Docker.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
die() { echo "❌ $*"; exit 1; }

# -------------------------------------------------------
# Lecture de .env clé par clé (pas de source)
# -------------------------------------------------------
read_env() {
    local key="$1" default="$2"
    if [ -f .env ]; then
        local val
        val=$(/usr/bin/grep -E "^${key}=" .env | /usr/bin/head -1 | /usr/bin/cut -d'=' -f2-)
        if [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi
    echo "$default"
}

write_env() {
    local key="$1" value="$2"
    if [ -f .env ]; then
        if /usr/bin/grep -qE "^${key}=" .env; then
            python3 -c "
import re
with open('.env', 'r') as f:
    content = f.read()
content = re.sub(r'^${key}=.*', '${key}=${value}', content, flags=re.MULTILINE)
with open('.env', 'w') as f:
    f.write(content)
"
        else
            echo "${key}=${value}" >> .env
        fi
    else
        echo "${key}=${value}" >> .env
    fi
}

DATA_DIR=$(read_env "DATA_DIR" "./data")
LLM_GGUF=$(read_env "LLM_GGUF" "")
LLM_MMPROJ=$(read_env "LLM_MMPROJ" "mmproj-F16.gguf")
GPU_TIER=$(read_env "GPU_TIER" "M")
COMPOSE_PROFILES=$(read_env "COMPOSE_PROFILES" "")

info "DATA_DIR: $DATA_DIR"
info "GPU_TIER: $GPU_TIER"
info "COMPOSE_PROFILES: ${COMPOSE_PROFILES:-<non défini>}"

# -------------------------------------------------------
# Détermination du modèle GGUF selon le GPU tier
# -------------------------------------------------------
if [ -z "$LLM_GGUF" ]; then
    if [ "$GPU_TIER" = "L" ]; then
        LLM_GGUF="Qwen3.8-27B-TurboFCFusion-735-882-Here-Uncen-NEO-CODER-MAX-MTP-Q4_K_M.gguf"
    else
        LLM_GGUF="Qwen3.5-9B-The-Defiant-Fable-Uncnr-Heretic-NEO-MAX-MTP-Q4_K_M.gguf"
    fi
    write_env "LLM_GGUF" "$LLM_GGUF"
    info "LLM_GGUF défini: $LLM_GGUF"
fi

# Déterminer le repo Hugging Face selon le GPU tier
if [ "$GPU_TIER" = "L" ]; then
    REPO_GGUF="DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF"
else
    REPO_GGUF="DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF"
fi

# -------------------------------------------------------
# Mode --select-only : définir LLM_GGUF dans .env, ne pas télécharger
# -------------------------------------------------------
if [ "${1:-}" = "--select-only" ] || [ "${SELECT_ONLY:-}" = "1" ]; then
    info "Mode --select-only: aucun téléchargement"
    ok "LLM_GGUF=${LLM_GGUF}"
    exit 0
fi

# -------------------------------------------------------
# Téléchargement avec reprise et vérification
# -------------------------------------------------------
declare -A downloaded_files=()
declare -A missing_files=()

download_file() {
    local url="$1" dest="$2" label="$3"
    local dirname
    dirname=$(dirname "$dest")
    mkdir -p "$dirname"

    if [ -f "$dest" ]; then
        info "Déjà téléchargé: $label ($dest)"
        downloaded_files["$label"]="$dest"
        return 0
    fi

    info "Téléchargement: $label"
    local part="${dest}.part"

    # Progression : -# si stderr est un terminal, sinon -sS
    local curl_flags="-fL -C - --retry 5 --retry-delay 5"
    if [ -t 2 ]; then
        curl_flags="$curl_flags -#"
    else
        curl_flags="$curl_flags -sS"
    fi

    if curl $curl_flags -o "$part" "$url"; then
        mv "$part" "$dest"
        downloaded_files["$label"]="$dest"
        ok "$label"
        return 0
    else
        local code=$?
        warn "Échec du téléchargement de $label (code $code)"
        missing_files["$label"]="$url"
        return $code
    fi
}

# -------------------------------------------------------
# Modèles GGUF (chat + vision) — via Hugging Face Hub
# -------------------------------------------------------
download_gguf() {
    info "Téléchargement des modèles GGUF..."
    info "Repo HF: $REPO_GGUF"
    info "Fichier GGUF: $LLM_GGUF"

    download_file "https://huggingface.co/${REPO_GGUF}/resolve/main/${LLM_GGUF}" "${DATA_DIR}/models/${LLM_GGUF}" "Modèle LLM ($LLM_GGUF)"

    # mmproj est fourni par l'utilisateur, pas téléchargé depuis HF
    if [ ! -f "${DATA_DIR}/models/${LLM_MMPROJ}" ]; then
        warn "Fichier mmproj manquant: ${LLM_MMPROJ} (fourni par l'utilisateur, pas téléchargé)"
        missing_files["mmproj"]="${DATA_DIR}/models/${LLM_MMPROJ}"
    else
        ok "Fichier mmproj présent: ${LLM_MMPROJ}"
    fi
}

# -------------------------------------------------------
# ComfyUI: modèles Qwen-Image 2.1 (seulement si profil comfyui)
# -------------------------------------------------------
download_comfyui_models() {
    # Vérifier si le profil comfyui est activé
    if [ -z "$COMPOSE_PROFILES" ] || ! echo "$COMPOSE_PROFILES" | /usr/bin/grep -q "comfyui"; then
        info "Profil comfyui non activé (COMPOSE_PROFILES='${COMPOSE_PROFILES:-<vide>}')"
        return 0
    fi

    info "Téléchargement des modèles ComfyUI (Qwen-Image 2.1)..."

    local MODELS_DIR="${DATA_DIR}/comfyui/models"
    local HF_COMFY="https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main"
    local HF_UNC="https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-Quantized/resolve/main"

    mkdir -p "${MODELS_DIR}/diffusion_models"
    mkdir -p "${MODELS_DIR}/text_encoders"
    mkdir -p "${MODELS_DIR}/vae"

    # Modèle diffusion NVFP4 (uncensored, quantisé, GPU Blackwell requis)
    download_file "${HF_UNC}/qwen-image-2.1-UC-NVFP4.safetensors" \
        "${MODELS_DIR}/diffusion_models/qwen-image-2.1-UC-NVFP4.safetensors" \
        "Diffusion model (qwen-image-2.1-UC-NVFP4)"

    # Text encoders
    download_file "${HF_COMFY}/text_encoders/qwen3vl_8b_bf16.safetensors" \
        "${MODELS_DIR}/text_encoders/qwen3vl_8b_bf16.safetensors" \
        "Text encoder (qwen3vl_8b_bf16)"

    download_file "${HF_COMFY}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors" \
        "${MODELS_DIR}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors" \
        "Text encoder t2i (qwen3.5_9b_qwen_image_2.1_pe_t2i)"

    download_file "${HF_COMFY}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors" \
        "${MODELS_DIR}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors" \
        "Text encoder i2i (qwen3.5_9b_qwen_image_2.1_pe_i2i)"

    # VAE
    download_file "${HF_COMFY}/vae/qwen_image_2.1_vae_bf16.safetensors" \
        "${MODELS_DIR}/vae/qwen_image_2.1_vae_bf16.safetensors" \
        "VAE (qwen_image_2.1_vae_bf16)"
}

# -------------------------------------------------------
# Vérification finale
# -------------------------------------------------------
verify_downloads() {
    local all_ok=true
    for label in "${!missing_files[@]}"; do
        warn "Fichier manquant: $label (${missing_files[$label]})"
        all_ok=false
    done
    if [ "$all_ok" = true ]; then
        ok "Tous les fichiers ont été téléchargés avec succès."
        return 0
    else
        die "Certains fichiers manquent. Voir les avertissements ci-dessus."
    fi
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
main() {
    download_gguf
    download_comfyui_models
    verify_downloads

    echo ""
    echo "📋 Modèles disponibles :"
    echo "  Chat: $LLM_GGUF (via llama-server)"
    echo "  Vision: $LLM_MMPROJ"
}

# Run main only if executed directly (not sourced)
if [ "$BASH_SOURCE" = "$0" ]; then
    main "$@"
fi
