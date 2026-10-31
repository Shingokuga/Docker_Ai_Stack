# Docker Stack Universelle

Stack auto-hébergée de 24 services Docker Compose (23 sans le profil optionnel comfyui) pour l'IA : chat, API, LLM local, TTS, transcription, conversion de documents, génération d'images, navigateur headless, base vectorielle, stockage, automatisation et suivi des appels LLM. Déployable en un clic sur une machine Ubuntu vierge.

## Services

| Service | Description |
|---|---|
| Caddy | Reverse proxy HTTPS |
| Open WebUI | Interface chat unifiée |
| LiteLLM | API et routage des modèles |
| llama-server | LLM local (llama.cpp) |
| Ollama + Ollama-init | Embeddings et modèle de décision |
| Whisper | Voix vers texte |
| Kokoro | Texte vers voix |
| Docling | Conversion de documents |
| ComfyUI | Génération d'images (profil optionnel) |
| Obscura + Obscura-MCP | Navigateur headless et serveur MCP |
| SearXNG | Recherche web |
| Qdrant | Base vectorielle |
| PostgreSQL | Base de données |
| Redis | Cache |
| ClickHouse + Langfuse (web/worker) | Suivi des appels LLM |
| S3 (RustFS) + S3-init | Stockage objet |
| n8n + n8n-worker | Automatisation |
| Portainer | Administration Docker |

## Installation

**Machine vierge (Ubuntu 22.04 ou 24.04) :**
```bash
bash bootstrap.sh
```
Installe Docker, le toolkit NVIDIA si un GPU est détecté, clone le dépôt et lance l'installation.

**Docker déjà installé :**
```bash
cd Docker_stack_universelle
./install.sh
```

`install.sh` crée `.env` et génère les secrets — ne pas préparer ce fichier à la main.

**Options communes :**
- `--yes` — sans questions
- `--no-gpu` — 17 services sans GPU, aucun modèle téléchargé
- `--config-only` — s'arrête après la validation de la configuration

Détails et architecture : [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Adresses

En supposant `<hôte>.<BASE_DOMAIN>` :

| Sous-domaine | Service |
|---|---|
| chat-ai | Open WebUI |
| automatisation | n8n |
| suivi-ia | Langfuse |
| admin | Portainer |
| documents | Docling |
| api | LiteLLM |
| stockage | Console S3 |
| images | ComfyUI (profil optionnel) |
| certificat | Certificat racine (via HTTP) |

## Prérequis

- Ubuntu 22.04 ou 24.04
- Docker et Compose v2 (installés par `bootstrap.sh`)
- GPU NVIDIA conseillé
- Espace disque et mémoire : voir [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- Pour les outils Open WebUI : voir [docs/OPEN-WEBUI-OUTILS.md](docs/OPEN-WEBUI-OUTILS.md)

## Documentation

- [Déploiement](docs/DEPLOYMENT.md)
- [Guide utilisateur](docs/USERS-GUIDE.md)
- [Profil ComfyUI](docs/PROFILE-COMFYUI.md)
- [Dépannage](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [API](docs/API-REFERENCE.md)
