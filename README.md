# Docker Stack Universelle

Stack 23 services AI en un clic : LLM local, TTS, transcription, génération d'image, navigateur headless, stockage, proxy SSL.

## Services

| Service | Port | Description |
|---|---|---|
| Open WebUI | 8080 | Interface chat unifiée |
| ComfyUI | 8188 | Génération d'image (profil comfyui) |
| Docling | 5001 | Conversion documents |
| LiteLLM | 4000 | Proxy de modèles |
| RustFS | 9001 | Stockage S3 |
| Whisper | 8084 | Transcription audio |
| Kokoro | 8880 | Synthèse vocale |
| Obscura | — | Navigateur headless |

## Profils

- **default** : 15 services sans GPU
- **comfyui** : +8 services GPU (whisper, comfyui, obscura, etc.)

## Prérequis

- Ubuntu 22.04+
- Docker 24+
- GPU NVIDIA (profil comfyui)
- RAM : 48GB+ (L) / 16GB+ (M) / 8GB+ (S)

## Installation

```bash
# 1. Bootstrap (installe git, docker, git-lfs)
curl -sL https://raw.githubusercontent.com/Shingokuga/Docker_stack_universelle/main/bootstrap.sh | sudo bash -s -- --yes

# 2. Installation complète
cd Docker_stack_universelle
./install.sh --yes --profile comfyui

# 3. Téléchargement des modèles
./download-models.sh
```

## Commandes

```bash
./stack up           # Démarrer
./stack ps           # Statut
./stack down         # Arrêter
./stack logs <svc>   # Logs d'un service
./stack exec <svc> <cmd>  # Commande dans un conteneur
./stack test         # Tests de santé
./stack config       # Validation de la configuration
```

## Variables clés

- `STACK_DOMAIN` : domaine principal (ex: stack.local)
- `WEBUI_ADMIN_EMAIL` : email admin Open WebUI
- `WEBUI_ADMIN_PASSWORD` : mot de passe admin
- `GPU_TIER` : palier GPU (L, M, S)

## Documentation

- [Déploiement](docs/DEPLOYMENT.md)
- [Guide utilisateur](docs/USERS-GUIDE.md)
- [Profil ComfyUI](docs/PROFILE-COMFYUI.md)
- [Dépannage](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [API](docs/API.md)
