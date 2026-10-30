# Architecture de la Stack Universelle AI

## Vue d'ensemble

La Stack Universelle AI est une plateforme de production complète qui orchestre 25 services Docker pour fournir une infrastructure d'intelligence artificielle intégrée. Tous les services communiquent sur un réseau Docker interne isolé (`ai_net`), avec un unique point d'entrée web via Caddy.

## Schéma d'architecture

```
                        ┌──────────────────────────────────────────────┐
                        │                  Internet                    │
                        └──────────────────────┬───────────────────────┘
                                               │ HTTPS (443)
                                               │ HTTP (80)
                                               ▼
                              ┌────────────────────────────┐
                              │      Caddy (reverse proxy) │
                              │  SSL/TLS, routing, ACME    │
                              └────────────────────────────┘
                                   │         │         │
              ┌────────────────────┘         │         └────────────────────┐
              │                              │                              │
   ┌──────────┴──────────┐   ┌───────────────┴──────────────┐   ┌──────────┴──────────┐
   │  Applications Web   │   │        API & Services        │   │   Administration    │
   │  ─────────────────  │   │  ────────────────────────    │   │  ──────────────────  │
   │  Open WebUI         │   │  LiteLLM (routage LLM)       │   │  Portainer          │
   │  N8N Automation     │   │  Docling OCR                 │   │  Langfuse Monitoring │
   │  SearXNG Search     │   │  Whisper STT                 │   │  Grafana Dashboards  │
   │  Langfuse Web       │   │  Kokoro TTS                  │   │                     │
   │  MinIO Console      │   │  ComfyUI Generation          │   │                     │
   │  Obscura Browser    │   │  Obscura MCP                 │   │                     │
   └─────────────────────┘   │  Ollama Embeddings          │   │                     │
                             └─────────────────────────────┘   │                     │
                                   │         │         │       │                     │
                    ┌──────────────┘         │         └───────┘                     │
                    │                        │                                       │
         ┌──────────┴──────────┐   ┌─────────┴─────────┐   ┌─────────────────────────┴──────────┐
         │    Modèles AI       │   │   Bases de données │   │   Infrastructure                 │
         │  ──────────────     │   │  ────────────────  │   │  ────────────────────             │
         │  llama.cpp Server   │   │  Postgres 17       │   │  Redis 7                       │
         │  Ollama             │   │  Qdrant (vecteurs) │   │  ClickHouse                    │
         │  Models GGUF        │   │  S3 (RustFS)       │   │  Loki (logs)                   │
         │                     │   │                    │   │  Prometheus (metrics)           │
         └─────────────────────┘   └────────────────────┘   └────────────────────────────────┘
```

## Services et Profils

### Core (noyau obligatoire)

| Service | Image | Rôle |
|---------|-------|------|
| postgres | postgres:17.11 | Base de données principale (n8n, litellm, langfuse, openwebui) |
| redis | redis:7.4.12 | Cache, file d'attente, sessions (mode noeviction) |
| qdrant | qdrant/qdrant:v1.20.0 | Base de données vectorielle pour les embeddings |
| llama-server | ggml-org/llama.cpp:server-cuda-b11206 | Inférence LLM locale GPU (GGUF) |
| ollama | ollama/ollama:0.40.13 | Serveur Ollama pour les embeddings |

### Applications

| Service | URL | Rôle |
|---------|-----|------|
| open-webui | https://chat-ai.{BASE_DOMAIN} | Interface chat avec outils MCP |
| n8n | https://automatisation.{BASE_DOMAIN} | Automation workflows |
| n8n-worker | - | Worker pour tâches n8n |
| litellm | https://api.{BASE_DOMAIN} | Routage unifié vers LLM |
| searxng | https://recherche.{BASE_DOMAIN} | Moteur de recherche privé |
| portainer | https://admin.{BASE_DOMAIN} | Administration Docker |

### Multimédia & Vision

| Service | Rôle |
|---------|------|
| comfyui | Génération d'images IA (Qwen-Image) |
| docling-serve | OCR et extraction de documents |
| whisper | Transcription audio (STT) |
| kokoro | Synthèse vocale (TTS) |
| obscura | Navigateur headless pour web scraping |
| obscura-mcp | Serveur MCP pour navigateur |

### Observabilité

| Service | URL | Rôle |
|---------|-----|------|
| grafana | https://monitoring.{BASE_DOMAIN} | Dashboards et visualisation |
| langfuse-web | https://suivi-ia.{BASE_DOMAIN} | Monitoring et tracing IA |
| langfuse-worker | - | Worker pour Langfuse |
| clickhouse | - | Base de données analytics Langfuse |

### Stockage

| Service | Rôle |
|---------|------|
| s3 (rustfs) | Stockage objet S3-compatible |
| s3-init | Initialisation des buckets S3 |

### Infrastructure

| Service | Rôle |
|---------|------|
| caddy | Reverse proxy SSL/TLS |
| ollama-init | Initialisation des modèles Ollama |

## Flux de données typique

### Exemple 1: Chat IA avec outils

```
Utilisateur → Open WebUI → Obscura MCP → Navigateur Obscura → Internet
                   ↓
              LiteLLM → llama-server (GPU) → Réponse LLM
                   ↓
              Open WebUI → Réponse à l'utilisateur
```

### Exemple 2: Workflow n8n

```
Trigger → N8N → LiteLLM → llama-server
           ↓
        Qdrant (recherche vectorielle)
           ↓
        Postgres (persistance)
```

### Exemple 3: Génération d'image

```
Utilisateur → Open WebUI → ComfyUI API → Qwen-Image (GPU)
                                            ↓
                                     Image générée → S3 (stockage)
```

## Réseau

- **Réseau interne**: `ai_net` (Docker bridge isolé)
- **Points d'entrée**: Seuls les ports 80/443 sont exposés via Caddy
- **Ports internes**: Chaque service expose son port uniquement sur `ai_net`

### Ports principaux internes

| Service | Port interne |
|---------|--------------|
| postgres | 5432 |
| redis | 6379 |
| qdrant | 6333 |
| llama-server | 8080 |
| litellm | 4000 |
| open-webui | 8080 |
| n8n | 5678 |
| comfyui | 8188 |
| docling-serve | 8000 |
| whisper | 9000 |
| kokoro | 8000 |
| obscura | 9222 (CDP) |
| obscura-mcp | 3000 |
| grafana | 3000 |
| langfuse | 3000 |
| s3 (rustfs) | 9000 |

## Stockage persistant

Toutes les données persistantes sont stockées dans `./data/` (configurable via `DATA_DIR`):

```
data/
├── postgres/          # Données Postgres
├── redis/             # Données Redis (AOF)
├── qdrant/            # Collections vectorielles
├── ollama/            # Modèles et données Ollama
├── models/            # Modèles GGUF et mmproj
├── open-webui/        # Données Open WebUI
├── n8n/               # Workflows et données n8n
├── n8n_shared/        # Fichiers partagés n8n
├── portainer/         # Données Portainer
├── caddy/             # Caches et certificats Caddy
├── whisper/           # Données Whisper
├── clickhouse/        # Données ClickHouse
├── s3/                # Stockage objet S3
└── langfuse/          # Données Langfuse
```
