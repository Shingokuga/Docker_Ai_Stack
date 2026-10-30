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

Voir le dossier `docs/` pour la documentation détaillée par profil.
