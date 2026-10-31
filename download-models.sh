#!/usr/bin/env bash
# download-models.sh — Télécharge les modèles pour la stack universelle
# Utilise .env pour les paramètres. Ne télécharge pas les images Docker.

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
die() { echo "❌ $*"; exit 1; }

# Vérifie si la GPU supporte le modèle NVFP4 (Blackwell, compute cap 10+)
check_blackwell_for_nvfp4() {
    local cap
    cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1)
    if [ -z "$cap" ]; then
        return 0
    fi
    # Extraire la partie entière du compute cap
    local major="${cap%%.*}"
    if [ "$major" -lt 10 ] 2>/dev/null; then
        warn "Le modèle qwen-image-2.1-UC-NVFP4 exige une carte NVIDIA Blackwell (compute capability 10 ou plus). Sur cette carte il ne fonctionnera pas : prévoir une variante fp8 ou int8."
    fi
    return 0
}

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

# -------------------------------------------------------
# Téléchargement avec reprise et vérification
# -------------------------------------------------------
download_file() {
    local url="$1" dest="$2" label="$3"
    local dirname
    dirname=$(dirname "$dest")
    mkdir -p "$dirname"

    if [ -f "$dest" ]; then
        info "Déjà téléchargé: $label ($dest)"
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
        ok "$label"
        return 0
    else
        local code=$?
        warn "Échec du téléchargement de $label (code $code)"
        return $code
    fi
}

# -------------------------------------------------------
# Modèles GGUF (chat + vision) — via Hugging Face Hub
# -------------------------------------------------------
download_gguf() {
    local data_dir="$1"
    local repo_gguf="$2"
    local llm_gguf="$3"
    local llm_mmproj="$4"
    local gpu_tier="$5"
    local download_count=0
    local missing_count=0

    info "Téléchargement des modèles GGUF..."
    info "Repo HF: $repo_gguf"
    info "Fichier GGUF: $llm_gguf"
    info "Fichier mmproj: $llm_mmproj"

    # Télécharger le GGUF principal
    if download_file "https://huggingface.co/${repo_gguf}/resolve/main/${llm_gguf}" "${data_dir}/models/${llm_gguf}" "Modèle LLM ($llm_gguf)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    # Télécharger le mmproj depuis le même repo (nom HF : mmproj-F16.gguf pour les deux paliers)
    if download_file "https://huggingface.co/${repo_gguf}/resolve/main/mmproj-F16.gguf" "${data_dir}/models/${llm_mmproj}" "Modèle mmproj ($llm_mmproj)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    # Vérifier que les deux fichiers sont présents
    if [ ! -f "${data_dir}/models/${llm_gguf}" ]; then
        warn "Fichier GGUF manquant: ${llm_gguf}"
        missing_count=$((missing_count + 1))
    else
        ok "Fichier GGUF présent: ${llm_gguf}"
    fi

    if [ ! -f "${data_dir}/models/${llm_mmproj}" ]; then
        warn "Fichier mmproj manquant: ${llm_mmproj}"
        missing_count=$((missing_count + 1))
    else
        ok "Fichier mmproj présent: ${llm_mmproj}"
    fi

    echo ""
    echo "📊 Statistiques du téléchargement GGUF :"
    echo "  Téléchargés: $download_count"
    echo "  Manquants: $missing_count"
    return $missing_count
}

# -------------------------------------------------------
# ComfyUI: modèles Qwen-Image 2.1 (seulement si profil comfyui)
# -------------------------------------------------------
download_comfyui_models() {
    local data_dir="$1"
    local compose_profiles="$2"

    if [ -z "$compose_profiles" ] || ! echo "$compose_profiles" | /usr/bin/grep -q "comfyui"; then
        info "Profil comfyui non activé (COMPOSE_PROFILES='${compose_profiles:-<vide>}')"
        return 0
    fi

    check_blackwell_for_nvfp4

    info "Téléchargement des modèles ComfyUI (Qwen-Image 2.1)..."

    local MODELS_DIR="${data_dir}/comfyui/models"
    local HF_COMFY="https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main"
    local HF_UNC="https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-Quantized/resolve/main"

    mkdir -p "${MODELS_DIR}/diffusion_models"
    mkdir -p "${MODELS_DIR}/text_encoders"
    mkdir -p "${MODELS_DIR}/vae"

    local download_count=0
    local missing_count=0

    # Modèle diffusion NVFP4 (uncensored, quantisé, GPU Blackwell requis)
    if download_file "${HF_UNC}/qwen-image-2.1-UC-NVFP4.safetensors" "${MODELS_DIR}/diffusion_models/qwen-image-2.1-UC-NVFP4.safetensors" "Diffusion model (qwen-image-2.1-UC-NVFP4)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    # Text encoders
    if download_file "${HF_COMFY}/text_encoders/qwen3vl_8b_bf16.safetensors" "${MODELS_DIR}/text_encoders/qwen3vl_8b_bf16.safetensors" "Text encoder (qwen3vl_8b_bf16)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    if download_file "${HF_COMFY}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors" "${MODELS_DIR}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors" "Text encoder t2i (qwen3.5_9b_qwen_image_2.1_pe_t2i)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    if download_file "${HF_COMFY}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors" "${MODELS_DIR}/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors" "Text encoder i2i (qwen3.5_9b_qwen_image_2.1_pe_i2i)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    # VAE
    if download_file "${HF_COMFY}/vae/qwen_image_2.1_vae_bf16.safetensors" "${MODELS_DIR}/vae/qwen_image_2.1_vae_bf16.safetensors" "VAE (qwen_image_2.1_vae_bf16)"; then
        download_count=$((download_count + 1))
    else
        missing_count=$((missing_count + 1))
    fi

    echo ""
    echo "📊 Statistiques du téléchargement ComfyUI :"
    echo "  Téléchargés: $download_count"
    echo "  Manquants: $missing_count"
    return $missing_count
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
main() {
    set -euo pipefail

    cd "$(dirname "${BASH_SOURCE[0]}")"

    local select_only=0
    if [ "${1:-}" = "--select-only" ] || [ "${SELECT_ONLY:-}" = "1" ]; then
        select_only=1
    fi

    # Lecture de la configuration
    local data_dir
    data_dir=$(read_env "DATA_DIR" "./data")
    local llm_gguf
    llm_gguf=$(read_env "LLM_GGUF" "")
    local llm_mmproj
    llm_mmproj=$(read_env "LLM_MMPROJ" "")
    local gpu_tier
    gpu_tier=$(read_env "GPU_TIER" "M")
    local compose_profiles
    compose_profiles=$(read_env "COMPOSE_PROFILES" "")

    info "DATA_DIR: $data_dir"
    info "GPU_TIER: $gpu_tier"
    info "COMPOSE_PROFILES: ${compose_profiles:-<non défini>}"
    info "LLM_GGUF: ${llm_gguf:-<non défini>}"
    info "LLM_MMPROJ: ${llm_mmproj:-<non défini>}"

    # Détermination des fichiers selon le GPU tier (si non déjà définis)
    if [ -z "$llm_gguf" ]; then
        if [ "$gpu_tier" = "L" ]; then
            llm_gguf="Qwen3.8-27B-TurboFCFusion-735-882-Here-Uncen-NEO-CODER-MAX-MTP-Q4_K_M.gguf"
        else
            llm_gguf="Qwen3.5-9B-The-Defiant-Fable-Uncnr-Heretic-NEO-MAX-MTP-Q4_K_M.gguf"
        fi
        info "LLM_GGUF défini automatiquement: $llm_gguf"
    fi

    if [ -z "$llm_mmproj" ]; then
        if [ "$gpu_tier" = "L" ]; then
            llm_mmproj="mmproj-qwen38-27b-F16.gguf"
        else
            llm_mmproj="mmproj-qwen35-9b-F16.gguf"
        fi
        info "LLM_MMPROJ défini automatiquement: $llm_mmproj"
    fi

    # Déterminer le repo Hugging Face selon le GPU tier
    local repo_gguf
    if [ "$gpu_tier" = "L" ]; then
        repo_gguf="DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF"
    else
        repo_gguf="DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF"
    fi

    # Mode --select-only : écrire LLM_GGUF et LLM_MMPROJ dans .env, ne pas télécharger
    if [ "$select_only" = 1 ]; then
        write_env "LLM_GGUF" "$llm_gguf"
        write_env "LLM_MMPROJ" "$llm_mmproj"
        info "Mode --select-only: aucun téléchargement"
        ok "LLM_GGUF=${llm_gguf}"
        ok "LLM_MMPROJ=${llm_mmproj}"
        exit 0
    fi

    # Télécharger les modèles GGUF
    if ! download_gguf "$data_dir" "$repo_gguf" "$llm_gguf" "$llm_mmproj" "$gpu_tier"; then
        die "Certains fichiers GGUF manquent."
    fi

    # Télécharger les modèles ComfyUI (si profil activé)
    if ! download_comfyui_models "$data_dir" "$compose_profiles"; then
        warn "Certains fichiers ComfyUI manquent."
    fi

    echo ""
    echo "📋 Modèles disponibles :"
    echo "  Chat: $llm_gguf (via llama-server)"
    echo "  Vision: $llm_mmproj"
}

# Run main only if executed directly (not sourced)
if [ "$BASH_SOURCE" = "$0" ]; then
    main "$@"
fi