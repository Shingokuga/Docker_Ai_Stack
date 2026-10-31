# Référence API

## Authentification

La plupart des services utilisent des tokens ou mots de passe configurés dans `.env`.

| Service | Méthode | Configuration |
|---------|---------|---------------|
| LiteLLM | Bearer token | `LITELLM_MASTER_KEY` |
| Open WebUI | Session (login) | `WEBUI_ADMIN_EMAIL/PASSWORD` |
| Qdrant | API Key | `QDRANT_API_KEY` |
| Redis | Password | `REDIS_PASSWORD` |
| Postgres | Password | `POSTGRES_PASSWORD` |
| S3 | Access Key/Secret | `S3_ROOT_USER/PASSWORD` |

---

## LiteLLM — Routage LLM

**Endpoint:** `http://litellm:4000` (interne) ou `https://api.{BASE_DOMAIN}` (externe)

### Completions (chat)

```bash
curl -X POST http://litellm:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxxx" \
  -d '{
    "model": "chat",
    "messages": [
      {"role": "user", "content": "Salut, comment ça va?"}
    ],
    "temperature": 0.7,
    "max_tokens": 1024
  }'
```

Réponse:
```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "Ça va bien, merci!"
      }
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 50,
    "total_tokens": 60
  }
}
```

### Embeddings

```bash
curl -X POST http://litellm:4000/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxxx" \
  -d '{
    "model": "text-embedding-3-small",
    "input": "Texte à encoder"
  }'
```

### Models disponibles

```bash
curl http://litellm:4000/v1/models \
  -H "Authorization: Bearer sk-xxxxxxx"
```

---

## Whisper — Transcription audio

**Endpoint:** `http://whisper:8000` (interne) ou `https://chat-ai.{BASE_DOMAIN}` (externe via Caddy)

### Transcription

```bash
curl -X POST http://whisper:8000/v1/audio/transcriptions \
  -H "Authorization: Bearer sk-xxxxxxx" \
  -F "file=@audio.mp3" \
  -F "model=large-v3"
```

### Traduction

```bash
curl -X POST http://whisper:8000/v1/audio/translations \
  -H "Authorization: Bearer sk-xxxxxxx" \
  -F "file=@audio.mp3" \
  -F "model=large-v3"
```

### Modèles disponibles

- `tiny`, `base`, `small`, `medium`, `large`, `large-v3`
- `Systran/faster-whisper-large-v3` (par défaut de la stack)

### Autres endpoints vérifiés

- `POST /v1/audio/speech` (TTS)
- `GET /v1/models` (liste des modèles)
- `GET /v1/audio/models`
- `GET /v1/audio/voices`
- `GET /health`

---

## Kokoro — Synthèse vocale

**Endpoint:** `http://kokoro:8880` (interne) ou `https://chat-ai.{BASE_DOMAIN}` (externe via Caddy)

### TTS

```bash
curl -X POST http://kokoro:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Bonjour, je suis une voix synthétisée.",
    "voice": "ff_siwis"
  }' \
  --output sortie.wav
```

### Liste des voix

```bash
curl http://kokoro:8880/v1/audio/voices
```

### Autres endpoints vérifiés

- `POST /v1/audio/voices/combine`
- `GET /health`

---

## Docling — OCR et documents

**Endpoint:** `http://docling-serve:5001` (interne) ou `https://documents.{BASE_DOMAIN}` (externe via Caddy)

### Conversion de document

```bash
curl -X POST http://docling-serve:5001/v1/convert/source \
  -F "file=@document.pdf"
```

### Extraction de texte

```bash
curl -X POST http://docling-serve:5001/extract_text \
  -F "file=@document.pdf"
```

### Formats supportés

- Entrée: PDF, DOCX, PPTX, XLSX, images (JPG, PNG)
- Sortie: Markdown, HTML, JSON, texte brut

### Autres endpoints vérifiés

- `GET /health`
- Autres chemins : à vérifier

---

## ComfyUI — Génération d'images

**Endpoint:** `http://comfyui:8188`

### Soumettre un workflow

```bash
curl -X POST http://comfyui:8188/api/prompt \
  -H "Content-Type: application/json" \
  -d @comfyui/workflows/text-to-image.json
```

### Statut de la file d'attente

```bash
curl http://comfyui:8188/api/queue
```

### Historique des générations

```bash
curl http://comfyui:8188/api/history
```

### Statistiques système

```bash
curl http://comfyui:8188/api/system_stats
```

### Annuler une génération

```bash
curl http://comfyui:8188/api/interrupt
```

---

## Open WebUI — API

**Endpoint:** `http://open-webui:8080`

### Authentification

```bash
curl -X POST http://open-webui:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "password"}'
```

### Liste des conversations

```bash
curl http://open-webui:8080/api/v1/conversations \
  -H "Authorization: Bearer <token>"
```

### Créer un chat complet

```bash
curl -X POST http://open-webui:8080/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "model": "chat",
    "messages": [{"role": "user", "content": "Salut!"}]
  }'
```

---

## Qdrant — Base vectorielle

**Endpoint:** `http://qdrant:6333`

### Créer une collection

```bash
curl -X POST http://qdrant:6333/collections/my_collection \
  -H "Content-Type: application/json" \
  -H "x-api-key: xxxxxxx" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    }
  }'
```

### Uploader un point

```bash
curl -X PUT http://qdrant:6333/collections/my_collection/points \
  -H "Content-Type: application/json" \
  -H "x-api-key: xxxxxxx" \
  -d '{
    "points": [{
      "id": 1,
      "vector": [0.1, 0.2, 0.3, ...],
      "payload": {"text": "Mon document"}
    }]
  }'
```

### Recherche

```bash
curl -X POST http://qdrant:6333/collections/my_collection/points/search \
  -H "Content-Type: application/json" \
  -H "x-api-key: xxxxxxx" \
  -d '{
    "vector": [0.1, 0.2, 0.3, ...],
    "limit": 10
  }'
```

---

## SearXNG — Recherche

**Endpoint:** `http://searxng:8080` (interne) ou `https://chat-ai.{BASE_DOMAIN}` (externe via Caddy)

### Recherche web — à vérifier

```bash
curl "http://searxng:8080/search?q=exemple&format=json"
```

### Recherche d'images — à vérifier

```bash
curl "http://searxng:8080/search?q=exemple&categories=images&format=json"
```

### Recherche de vidéos — à vérifier

```bash
curl "http://searxng:8080/search?q=exemple&categories=videos&format=json"
```

### Autres endpoints vérifiés

- `GET /healthz` (vérifié)

---

## Langfuse — API

**Endpoint:** `http://langfuse-web:3000` (interne) ou `https://suivi-ia.{BASE_DOMAIN}` (externe via Caddy)

### Créer une trace — à vérifier

```bash
curl -X POST http://langfuse-web:3000/api/public/traces \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <pk:sk>" \
  -d '{
    "name": "mon_appel_llm",
    "userId": "user_123",
    "session_id": "session_abc"
  }'
```

### Créer un span — à vérifier

```bash
curl -X POST http://langfuse-web:3000/api/public/spans \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic <pk:sk>" \
  -d '{
    "traceId": "<trace_id>",
    "name": "appel_llm",
    "input": {"prompt": "..."},
    "output": {"response": "..."},
    "startTime": "2026-01-01T00:00:00Z"
  }'
```

### Autres endpoints vérifiés

- `GET /api/public/health` (vérifié)
