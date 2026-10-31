# Guide utilisateur

## Accès et certificat

Chaque service est accessible en HTTPS sur un sous-domaine de `<hôte>.<BASE_DOMAIN>` (BASE_DOMAIN est défini dans le fichier `.env`, valeur par défaut `local`). Caddy utilise un certificat TLS interne auto-signé.

Pour installer le certificat racine dans votre navigateur :

```
http://certificat.<BASE_DOMAIN>/root.crt
```

Si vous n'utilisez pas DNS, ajoutez une entrée dans le fichier `hosts` de votre poste. Cette étape est conseillée en fin d'installation.

Sans adresse publique (internes au réseau Docker uniquement) : whisper, kokoro, searxng, ollama, qdrant.

## Open WebUI

**Adresse** : `https://chat-ai.<BASE_DOMAIN>`

Chat IA avec LLM local, recherche web et outils MCP.

**Connexion** : compte admin créé au premier démarrage. Les credentials sont les valeurs de `WEBUI_ADMIN_EMAIL` et `WEBUI_ADMIN_PASSWORD` dans `.env`.

**Fonctionnalités configurées** :

- **Voix** : transcription audio via Whisper en entrée (modèle `whisper-1` = `Systran/faster-whisper-large-v3`) et synthèse vocale via Kokoro en sortie (voix par défaut `ff_siwis`).
- **Recherche web** : activée, moteur SearXNG.
- **RAG** : embeddings `embeddinggemma` via LiteLLM, base vectorielle Qdrant.
- **Outils MCP** : Obscura (navigateur) ; Context7 (documentation technique, uniquement si `CONTEXT7_API_KEY` est renseignée dans `.env`). La configuration et l'utilisation des outils MCP sont détaillées dans `docs/OPEN-WEBUI-OUTILS.md`.

## ComfyUI

**Adresse** : `https://images.<BASE_DOMAIN>` (uniquement si `COMPOSE_PROFILES=comfyui` est défini dans `.env`)

Génération d'images IA avec Qwen-Image 2.1.

Les workflows au format API sont fournis dans le dépôt :

- `comfyui/workflows/text-to-image.json` — génération à partir de texte
- `comfyui/workflows/image-to-image.json` — modification d'image (2 images en entrée ; le workflow peut en recevoir jusqu'à 10)

Ces fichiers ne sont pas montés dans le conteneur. Les images générées sont écrites dans le répertoire `data/comfyui/output` sur le serveur (pas de route web dédiée).

Détails d'interface : à vérifier. API : voir `docs/PROFILE-COMFYUI.md`.

## Voix (Whisper et Kokoro)

Services internes sans adresse publique, utilisés par Open WebUI.

### Whisper (transcription)

**Adresse interne** : `http://whisper:8000`

- `POST /v1/audio/transcriptions` — transcrire un audio (modèle `whisper-1`)

### Kokoro (synthèse vocale)

**Adresse interne** : `http://kokoro:8880`

- `POST /v1/audio/speech` — synthétiser un audio
- `GET /v1/audio/voices` — liste des voix disponibles
- Voix par défaut : `ff_siwis` (Open WebUI l'appelle avec `model=kokoro`)

Exemple d'appel Kokoro (depuis un conteneur du réseau Docker ; format de sortie à vérifier) :

```bash
curl -X POST http://kokoro:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"kokoro","input":"Bonjour","voice":"ff_siwis"}'
```

## Docling

**Adresse** : `https://documents.<BASE_DOMAIN>`

Extraction de contenu de documents (OCR, PDF, etc.).

- `POST /v1/convert/source` — convertir un document

## API LiteLLM

**Adresse** : `https://api.<BASE_DOMAIN>/v1`

Passerelle OpenAI-compatible pour les modèles chat et embeddings.

**Authentification** : en-tête `Authorization: Bearer <LITELLM_MASTER_KEY>` (clé définie dans `.env`).

**Modèles exposés** : `chat` (LLM local) et `embeddinggemma` (embeddings).

Les corps de requête complets ne sont pas listés ici ; voir `docs/API-REFERENCE.md`.

## Stockage S3 (RustFS)

**Adresse** : `https://stockage.<BASE_DOMAIN>`

Console web de stockage objet compatible S3 (RustFS).

**Connexion** : les credentials sont les valeurs de `S3_ROOT_USER` et `S3_ROOT_PASSWORD` dans `.env`.

## Langfuse

**Adresse** : `https://suivi-ia.<BASE_DOMAIN>`

Monitoring et traçage des applications IA.

**Connexion** : compte admin créé à l'initialisation. Les credentials sont les valeurs de `LANGFUSE_INIT_USER_EMAIL` et `LANGFUSE_INIT_USER_PASSWORD` dans `.env`. L'inscription de nouveaux utilisateurs est désactivée.

## n8n

**Adresse** : `https://automatisation.<BASE_DOMAIN>`

Automation et orchestration de workflows.

Aucun compte n'est pré-créé par la stack. Le premier accès demande de créer un compte utilisateur (comportement standard de n8n).

## SearXNG

Service interne sans adresse publique, utilisé comme moteur de recherche web par Open WebUI.

## Portainer

**Adresse** : `https://admin.<BASE_DOMAIN>`

Administration de l'infrastructure Docker.

Aucun compte n'est pré-créé par la stack. Le premier accès demande de créer un compte utilisateur (comportement standard de Portainer).
