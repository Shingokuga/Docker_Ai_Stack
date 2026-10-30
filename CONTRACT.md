# CONTRACT — noms partagés entre lot A (compose) et lot B (scripts)

Racine: /home/shingokuga/Docker_stack_universelle  (NVIDIA only, clients amd64 Linux, Docker Compose v2+)

## Fichiers d'env
- versions.env  : TOUTES les images, épinglées (jamais latest). Variables IMG_<SERVICE>=repo:tag. Seul fichier modifié par une release.
- .env          : généré par install.sh (secrets + config client). Jamais commité. .env.example commité (valeurs vides/exemple).
- .env.dev      : surcharge pour la machine de test (HTTP_PORT=8088 HTTPS_PORT=8443 COMPOSE_PROJECT_NAME=ustack-dev, data dir séparé).
- Appel compose unique: ./stack <args>  == docker compose --env-file versions.env --env-file .env [--env-file .env.dev si STACK_ENV=dev] "$@"

## Variables de config (dans .env)
COMPOSE_PROJECT_NAME (def ustack), BASE_DOMAIN (def local), HTTP_PORT (80), HTTPS_PORT (443), TZ (Europe/Paris), DATA_DIR (def ./data),
GPU_TIER (S|M|L), LLM_GGUF (nom de fichier dans DATA_DIR/models), LLM_MMPROJ (idem), LLM_CTX, LLM_ALIAS (nom de modèle exposé par LiteLLM, def "chat"),
EMBED_MODEL (def embeddinggemma-2:latest), DECISION_MODEL (def kev:9b-q4_K_M), WHISPER_MODEL, KOKORO_VOICE_DEFAULT.

## Secrets générés (dans .env, 32+ chars aléatoires, openssl rand)
POSTGRES_PASSWORD REDIS_PASSWORD QDRANT_API_KEY LITELLM_MASTER_KEY LITELLM_SALT_KEY WEBUI_SECRET_KEY N8N_ENCRYPTION_KEY
NEXTAUTH_SECRET LANGFUSE_SALT LANGFUSE_ENCRYPTION_KEY(64 hex) CLICKHOUSE_PASSWORD S3_ROOT_USER S3_ROOT_PASSWORD SEARXNG_SECRET
LANGFUSE_INIT_ORG_ID LANGFUSE_INIT_PROJECT_ID LANGFUSE_INIT_PROJECT_PUBLIC_KEY(pk-lf-...) LANGFUSE_INIT_PROJECT_SECRET_KEY(sk-lf-...)
LANGFUSE_INIT_USER_EMAIL LANGFUSE_INIT_USER_PASSWORD (demandés ou générés par install.sh)
=> LiteLLM utilise LANGFUSE_INIT_PROJECT_* pour son callback: tracing automatique, zéro clic.

## Services (noms compose = noms DNS internes) et ports INTERNES
caddy(80,443 SEULS ports publiés) portainer(9000) postgres(5432) redis(6379) qdrant(6333) ollama(11434) llama-server(8080)
litellm(4000) open-webui(8080) searxng(8080) n8n(5678) n8n-worker docling-serve(5001) whisper(8000) kokoro(8880)
langfuse-web(3000) langfuse-worker(3030) clickhouse(8123,9000) s3(9000, console 9001; RustFS)
Init one-shot: pg-init (via /docker-entrypoint-initdb.d), ollama-init (pull EMBED_MODEL + DECISION_MODEL), s3-init (bucket langfuse)
Profils optionnels: comfyui (lot ultérieur), tailscale, cloudflared, komodo (agent Periphery).
Réseau unique: ai_net. AUCUN autre port publié sur l'hôte que caddy.

## Noms d'URL (https://<nom>.${BASE_DOMAIN})
chat-ai→open-webui:8080  automatisation→n8n:5678  suivi-ia→langfuse-web:3000  admin→portainer:9000
documents→docling-serve:5001 (UI)  api→litellm:4000  stockage→s3:9001  images→comfyui:8188 (profil comfyui)
certificat → site HTTP simple (http://certificat.${BASE_DOMAIN}) qui sert le root CA interne de Caddy (/data/caddy/pki/authorities/local/root.crt) + petite page d'aide FR.
Chaque nom DOIT être publié en mDNS par install.sh (avahi) => lot B lit la liste depuis scripts/hostnames.txt (1 nom court par ligne, écrit par lot A: caddy/hostnames.txt).

## Base de données Postgres 17 (un seul conteneur): bases n8n, litellm, langfuse, openwebui — créées par config/postgres/init-databases.sh

## Modèles
- Chat: llama-server (llama.cpp, --jinja obligatoire pour tool calling), GGUF MTP. L (>24 Go VRAM): Qwen3.8-27B ...MTP-Q4_K_M.gguf (18.5 Go) — repo DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF ; S/M (<=24 Go): Qwen3.5-9B-The-Defiant-Fable-Uncnr-Heretic-NEO-MAX-MTP-Q4_K_M.gguf (6.98 Go) — repo DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF. mmproj-F16.gguf dans chaque repo (vision).
- Embeddings: Ollama embeddinggemma-2:latest (768d, ne JAMAIS changer après déploiement client).
- Décision (n8n, pas chat): Ollama kev:9b-q4_K_M (les tags nvfp4 sont MLX=Apple, inutilisables).
- LiteLLM config/litellm/config.yaml expose: chat (llama-server), embeddinggemma (ollama), + callbacks langfuse.

## ComfyUI (profil comfyui) — exigence GPU (décision Kévin 2026-10-30)
- Le service comfyui DOIT utiliser l'ancre x-gpu (NVIDIA), comme ollama / llama-server / docling-serve / whisper / kokoro. Sans GPU, génération d'image inutilisable.
- Image: Dockerfile maison (aucune image officielle) depuis Comfy-Org/ComfyUI épinglé sur une release, PyTorch CUDA, amd64.
- Démarrage avec --listen 0.0.0.0 --disable-smart-memory (décharge les modèles vers la RAM après usage => VRAM libérée pour le LLM). Libération explicite possible: POST http://comfyui:8188/free {"unload_models":true,"free_memory":true}.
- Port interne 8188, exposé via Caddy sous images.${BASE_DOMAIN}. Open WebUI branché par env: ENABLE_IMAGE_GENERATION=true IMAGE_GENERATION_ENGINE=comfyui COMFYUI_BASE_URL=http://comfyui:8188 (+ COMFYUI_WORKFLOW / COMFYUI_WORKFLOW_NODES quand les workflows seront choisis).
- Palier VRAM: sur GPU_TIER S/M, LLM et ComfyUI se partagent la carte tour à tour (smoke test à écrire); palier L: marge à mesurer.
