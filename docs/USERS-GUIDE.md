# Guide utilisateur

## Open WebUI — Interface de chat IA

### Accès

Se connecter à `https://chat-ai.{BASE_DOMAIN}` avec les credentials admin configurés dans `.env`.

### Fonctionnalités

- **Chat conversationnel** avec le LLM local
- **Outils MCP** pour navigation web et documentation
- **Support multimédia** (images, audio)
- **Gestion des conversations** (historique, export)

### Utilisation des outils MCP

Pour utiliser les outils MCP (Obscura, Context7) dans une conversation:

1. Dans le chat, taper `/tools` ou cliquer sur l'icône "Outils"
2. Cocher les outils à activer pour cette conversation
3. Les outils seront automatiquement invoqués par le LLM quand nécessaire

#### Navigateur web (Obscura)

Le LLM peut naviguer sur internet pour vous:
- "Quelle est la météo à Paris?"
- "Résume cet article: [URL]"
- "Remplis ce formulaire: [URL]"

#### Documentation (Context7)

Le LLM peut rechercher de la documentation technique:
- "Comment utiliser React Router v6?"
- "Donne-moi un exemple de code avec FastAPI"

### Limites

- Les outils MCP sont réservés aux comptes **admin**
- Une seule session de navigation Obscura à la fois (serveur mono-séance)
- Nécessite une connexion internet

## ComfyUI — Génération d'images

### Accès

Se connecter à `https://images.{BASE_DOMAIN}`.

### Génération d'image depuis le texte

1. Charger le workflow `text-to-image.json` (menu Load)
2. Modifier le champ "prompt" avec votre description
3. Cliquer sur "Queue Prompt"
4. Attendre la génération (quelques secondes à plusieurs minutes selon le modèle)

### Exemple de prompt

```
A futuristic city at sunset, neon lights reflecting on wet streets,
cyberpunk style, highly detailed, 4K resolution
```

### Modification d'image

1. Charger le workflow `image-to-image.json`
2.Uploader votre image source
3. Modifier le prompt pour décrire les changements souhaités
4. Lancer la génération

### Stockage des outputs

Les images générées sont stockées dans:
- Local: `data/comfyui/output/`
- Web: `https://images.{BASE_DOMAIN}/output/`

## Whisper — Transcription audio

### API

Whisper expose une API compatible OpenAI sur `http://whisper:9000`.

### Exemple de transcription

```bash
# Envoyer un fichier audio pour transcription
curl -X POST http://whisper:9000/v1/audio/transcriptions \
  -H "Authorization: Bearer sk-xxxxxxx" \
  -F "file=@mon_audio.mp3" \
  -F "model=large-v3"

# Réponse JSON
{
  "text": "Bonjour, je suis un audio en français qui est transcrit."
}
```

### Formats supportés

- mp3, wav, flac, ogg, m4a, webm

## Kokoro — Synthèse vocale

### API

Kokoro expose une API sur `http://kokoro:8000`.

### Exemple de synthèse

```bash
# Générer de l'audio depuis du texte
curl -X POST http://kokoro:8000/api/tts \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Bonjour, je suis une voix synthétisée.",
    "voice": "ff_siwis",
    "format": "wav"
  }' \
  --output sortie.wav
```

### Voix disponibles

- `ff_siwis` — Voix française par défaut
- Autres voix disponibles selon la configuration

## MinIO Console — Gestion des fichiers

### Accès

Se connecter à `https://stockage.{BASE_DOMAIN}` avec les credentials S3 configurés.

### Fonctionnalités

- Créer et gérer les buckets
- Upload et download de fichiers
- Partage de liens
- Gestion des permissions

### API S3

Compatible avec l'API S3 standard AWS. Utilisez n'importe quel client S3:

```bash
# Exemple avec aws cli
aws s3 ls s3://langfuse
aws s3 cp fichier.txt s3://mon-bucket/
```

## Langfuse — Monitoring IA

### Accès

Se connecter à `https://suivi-ia.{BASE_DOMAIN}`.

### Fonctionnalités

- **Tracing**: Suivre chaque appel LLM
- **Évaluation**: Mesurer la qualité des réponses
- **Sessions**: Analyser les conversations
- **Dashboards**: Métriques d'usage et de performance

### Concepts

- **Trace**: Une unité de travail (ex: un appel API)
- **Span**: Une opération dans une trace (ex: appel LLM, recherche)
- **Observation**: Données capturées (tokens, durée, coût)

## SearXNG — Recherche privée

### Accès

Se connecter à `https://recherche.{BASE_DOMAIN}`.

### Fonctionnalités

- Recherche web sans tracking
- Résultats agrégés de multiples moteurs
- Recherche d'images, vidéos, news
- API JSON pour intégration

### API

```bash
curl "http://searxng:8080/search?q=exemple&format=json"
```

## N8N — Automation

### Accès

Se connecter à `https://automatisation.{BASE_DOMAIN}`.

### Fonctionnalités

- Création de workflows visuels
- Intégration avec des centaines d'applications
- Scheduling et triggers
- Webhooks

### Exemples de workflows

- Envoyer un email quand un nouveau message arrive
- Traiter automatiquement des documents PDF
- Mettre à jour un CRM avec des données web

## Grafana — Dashboards

### Accès

Se connecter à `https://monitoring.{BASE_DOMAIN}`.

### Dashboards disponibles

- **Système**: CPU, RAM, disque, réseau
- **Docker**: Conteneurs, images, volumes
- **Services**: Statuts et performances des services
- **LLM**: Utilisation, tokens, latence

## Portainer — Administration Docker

### Accès

Se connecter à `https://admin.{BASE_DOMAIN}`.

### Fonctionnalités

- Gestion des conteneurs
- Gestion des images
- Logs et monitoring
- Configuration réseau
- Volumes et stockage
