#!/usr/bin/env bash
# download-models.sh — Télécharge les modèles pour la stack universelle
# Utilise .env pour les paramètres et versions.env pour les images.
set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="."

# Charger les variables
if [ -f .env ]; then
    . .env
fi

DATA_DIR="${DATA_DIR:-./data}"
LLM_GGUF="${LLM_GGUF:-}"
LLM_MMPROJ="${LLM_MMPROJ:-mmproj-F16.gguf}"
EMBED_MODEL="${EMBED_MODEL:-embeddinggemma-2:latest}"
DECISION_MODEL="${DECISION_MODEL:-kev:9b-q4_K_M}"
WHISPER_MODEL="${WHISPER_MODEL:-Systran/faster-whisper-large-v3}"
GPU_TIER="${GPU_TIER:-M}"

info() { echo "ℹ  $*"; }
ok() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

# -------------------------------------------------------
# Modèles GGUF (chat + vision) — via Hugging Face Hub
# -------------------------------------------------------
download_gguf() {
    info "Téléchargement des modèles GGUF..."

    # Déterminer le repo Hugging Face selon le GPU tier
    local repo
    if [ "$GPU_TIER" = "L" ]; then
        # Palier L: Qwen3.8-27B MTP Q4_K_M (18.5 Go)
        repo="DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF"
        LLM_GGUF="${LLM_GGUF:-Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-Q4_K_M.gguf}"
    else
        # Palier S/M: Qwen3.5-9B MTP Q4_K_M (6.98 Go)
        repo="DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF"
        LLM_GGUF="${LLM_GGUF:-Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-Q4_K_M.gguf}"
    fi

    mkdir -p "${DATA_DIR}/models"

    # Téléchargement avec reprise (curl -C -)
    info "Téléchargement: $LLM_GGUF"
    curl -L -C - -o "${DATA_DIR}/models/${LLM_GGUF}" \
        "https://huggingface.co/${repo}/resolve/main/${LLM_GGUF}" || warn "Échec du téléchargement de $LLM_GGUF"

    info "Téléchargement: $LLM_MMPROJ"
    curl -L -C - -o "${DATA_DIR}/models/${LLM_MMPROJ}" \
        "https://huggingface.co/${repo}/resolve/main/${LLM_MMPROJ}" || warn "Échec du téléchargement de $LLM_MMPROJ"

    ok "Modèles GGUF téléchargés"
}

# -------------------------------------------------------
# Ollama: pull des modèles d'embedding et décision
# -------------------------------------------------------
ollama_pull() {
    info "Pull des modèles Ollama (via ollama-init)..."
    docker compose --env-file versions.env --env-file .env up -d ollama ollama-init

    # Attendre la complétion de ollama-init
    docker compose --env-file versions.env --env-file .env wait ollama-init || warn "ollama-init a échoué"
    ok "Modèles Ollama pullés"
}

# -------------------------------------------------------
# Whisper et Kokoro: téléchargés automatiquement au démarrage
# -------------------------------------------------------
wait_voice_models() {
    info "Whisper et Kokoro téléchargent leurs modèles au démarrage des conteneurs"
    info "Patientez quelques minutes avant d'utiliser la stack"
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
download_gguf
ollama_pull
wait_voice_models

ok "Téléchargement des modèles terminé"
echo ""
echo "📋 Modèles disponibles :"
echo "  Chat: $LLM_GGUF (via llama-server)"
echo "  Vision: $LLM_MMPROJ"
echo "  Embeddings: $EMBED_MODEL (Ollama)"
echo "  Décision: $DECISION_MODEL (Ollama)"
echo "  Whisper: $WHISPER_MODEL (auto au démarrage)"
echo "  Kokoro: auto au démarrage"
