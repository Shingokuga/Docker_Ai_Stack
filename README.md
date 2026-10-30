# Stack Universelle d'IA en Production

Docker Compose stack professionnelle avec 25 services, GPU NVIDIA, et supervision complète. Prête pour la production.

## Services

- LLM local (llama.cpp) avec GPU
- Transcription vocale (Whisper)
- Synthèse vocale (Kokoro)
- Génération d'images (ComfyUI)
- Vision (Obscura)
- OCR (Docling)
- Routage IA (LiteLLM)
- Stockage objet (MinIO)
- Supervision (Grafana, Prometheus, Loki)
- Et plus...

## Installation

```bash
cd Docker_stack_universelle
cp .env.example .env
# Éditer .env avec vos secrets
./install.sh
```

## Documentation

### Guides principaux

- [Architecture](docs/ARCHITECTURE.md) — Vue d'ensemble de l'architecture et des services
- [Déploiement](docs/DEPLOYMENT.md) — Guide de déploiement pas à pas
- [Guide utilisateur](docs/USERS-GUIDE.md) — Utilisation des différents services
- [Référence API](docs/API-REFERENCE.md) — Documentation des API exposées
- [Maintenance](docs/MAINTENANCE.md) — Sauvegardes, monitoring, mises à jour
- [Dépannage](docs/TROUBLESHOOTING.md) — Guide de résolution des problèmes
- [Développeurs](docs/DEVELOPERS.md) — Extension de la stack

### Documentation technique

- [Outils Open WebUI](docs/OPEN-WEBUI-OUTILS.md) — Configuration des outils MCP
- [Profil ComfyUI](docs/PROFILE-COMFYUI.md) — Documentation détaillée de ComfyUI

## URLs de la stack

| Service | URL |
|---------|-----|
| Chat IA | `https://chat-ai.{BASE_DOMAIN}` |
| Automation | `https://automatisation.{BASE_DOMAIN}` |
| Monitoring IA | `https://suivi-ia.{BASE_DOMAIN}` |
| Admin | `https://admin.{BASE_DOMAIN}` |
| API | `https://api.{BASE_DOMAIN}` |
| Documents | `https://documents.{BASE_DOMAIN}` |
| Stockage | `https://stockage.{BASE_DOMAIN}` |
| Recherche | `https://recherche.{BASE_DOMAIN}` |
| Monitoring | `https://monitoring.{BASE_DOMAIN}` |

## Prérequis

- Ubuntu 22.04/24.04 LTS
- Docker + Docker Compose v2
- GPU NVIDIA (recommandé)
- 16 Go+ RAM
- 100 Go+ stockage SSD
