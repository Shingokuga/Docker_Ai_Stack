# Research notes — stack universelle clients (2026-10-30)

## Hôte de dev (spark-33fd)
- Docker 29.2.1, Compose v5.0.2, GPU NVIDIA GB10 (arm64, 121 Go RAM unifiée). Clients = probablement amd64 → images multi-arch obligatoires.

## Versions upstream vérifiées (API GitHub, 2026-10-29/30)
| Brique | Dernière version | Remarque |
|---|---|---|
| Portainer | 2.45.3 LTS | OK |
| Open WebUI | v0.12.5 | OK |
| n8n | 2.45.6 | OK |
| Docling-serve | v1.38.2 | actif; image ghcr.io/docling-project/docling-serve-cu126 (GPU) / docling-serve (CPU) |
| Langfuse | **v4.72.0** | local-ai-packaged est resté en v3 ; v4 = registre docker.langfuse.com/langfuse/langfuse:4 + langfuse-worker:4 |
| Speaches | v0.9.0-rc.3 (27/12/2025), dernier commit 18/04/2026 | **peu maintenu** (RC depuis 10 mois, 1 maintainer) |
| Kokoro-FastAPI (remsky) | v0.9.1 (28/10/2026) | actif, alternative TTS |

## Langfuse v4 (compose officiel) = 6 conteneurs
langfuse-web, langfuse-worker, clickhouse 25.12, minio (chainguard), redis 7 (--maxmemory-policy noeviction obligatoire), postgres 17.
- Langfuse ne peut PAS partager un Redis "cache" avec éviction : Redis dédié (ou noeviction global).
- Postgres partageable (base langfuse dédiée). Minio nécessaire (event/media upload).

## Speaches (API OpenAI-compatible)
- STT: POST /v1/audio/transcriptions (faster-whisper, modèles Systran/faster-whisper-*)
- TTS: POST /v1/audio/speech (Kokoro ONNX speaches-ai/Kokoro-82M-v1.0-ONNX, voix ex. af_heart; piper)
- Modèles téléchargés à la demande (speaches-cli model download) → prévoir un job d'init.
- Images: ghcr.io/speaches-ai/speaches:latest-cuda / latest-cpu. Healthcheck /health. Port 8000.
- Limite: opus/aac non supportés en TTS.
=> API OK, remplace bien kokoro + whisper avec un seul conteneur. Risque = maintenance.

## local-ai-packaged (coleam00)
- Caddy: un bloc {$X_HOSTNAME} { reverse_proxy svc:port } par service, défaut :800X en local → HTTPS auto Let's Encrypt si vrai domaine. import /etc/caddy/addons/*.conf pour extensions.
- Profils compose cpu / gpu-nvidia / gpu-amd pour Ollama. Overrides private / public.
- start_services.py orchestre plusieurs compose (on préfère un seul compose + install.sh).
- expose: (pas ports:) pour tout sauf Caddy ; cap_drop ALL sur Caddy/Redis/SearXNG ; logs json-file limités.

## Open WebUI — variables d'env vérifiées dans config.py (main)
CONTENT_EXTRACTION_ENGINE, DOCLING_SERVER_URL, DOCLING_API_KEY, DOCLING_PARAMS,
AUDIO_STT_ENGINE, AUDIO_STT_OPENAI_API_BASE_URL, AUDIO_STT_MODEL,
AUDIO_TTS_ENGINE, AUDIO_TTS_OPENAI_API_BASE_URL, AUDIO_TTS_MODEL, AUDIO_TTS_VOICE,
VECTOR_DB (=qdrant), QDRANT_URI, RAG_EMBEDDING_ENGINE, RAG_OPENAI_API_BASE_URL,
ENABLE_WEB_SEARCH, WEB_SEARCH_ENGINE (=searxng), SEARXNG_QUERY_URL, OLLAMA_BASE_URL.
=> câblage OWUI <-> Docling/Speaches/Qdrant/SearXNG/Ollama 100 % par env.

## Ta stack existante (Montage_docker_stack)
Reprendre: anchor x-logging, healthchecks, limites mem/cpu, n8n queue mode (Redis DB index séparé), N8N_DEFAULT_BINARY_DATA_MODE=filesystem, EXECUTIONS_DATA_PRUNE, secrets via .env, cloudflared.
Ne pas reprendre (perso / risque client): ports 5432/6379/9000 exposés, docker.sock monté dans n8n, NODE_FUNCTION_ALLOW_BUILTIN=child_process, postgres:15, :latest partout, ports llama.cpp/vllm/comfyui, domaine en dur, clés Google x15.
