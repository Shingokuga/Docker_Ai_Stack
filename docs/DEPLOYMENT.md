# Guide de déploiement

## Prérequis système

### Configuration minimale

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| OS | Ubuntu 22.04 LTS / 24.04 LTS | Ubuntu 24.04 LTS |
| RAM | 16 Go | 32 Go+ |
| Stockage | 100 Go SSD | 500 Go+ NVMe |
| GPU NVIDIA | 8 Go VRAM | 24 Go+ VRAM |
| Pilote NVIDIA | ≥ 570 | ≥ 580 |

### Logiciels requis

- Docker Engine (dernière version)
- Docker Compose v2 (plugin)
- git + git-lfs
- curl, jq

## Installation étape par étape

### Étape 1: Bootstrap (machine vierge)

```bash
# Télécharger bootstrap.sh sur la machine cible
curl -LO https://github.com/votre-repo/stack-universelle/raw/main/bootstrap.sh
chmod +x bootstrap.sh

# Exécuter le bootstrap
STACK_REPO_URL=https://github.com/votre-repo/stack-universelle.git ./bootstrap.sh
```

Le bootstrap installe:
- Paquets système (git, curl, jq, ca-certificates)
- Docker + Docker Compose
- NVIDIA Container Toolkit (si GPU détecté)
- git-lfs
- Clone le dépôt de la stack

### Étape 2: Installation

```bash
cd stack-universelle

# Installer et lancer la stack
./install.sh
```

L'installateur:
1. Vérifie les prérequis (Docker, RAM, disque)
2. Crée les répertoires de données avec les permissions correctes
3. Copie `.env.example` → `.env` et génère les secrets
4. Pull toutes les images Docker
5. Démarre la stack en mode détaché

### Étape 3: Configuration .env

Éditez `.env` avec vos paramètres:

```bash
nano .env
```

#### Sections critiques

**Domaine:**
```env
BASE_DOMAIN=local          # Remplacer par votre domaine (ex: ai.entreprise.fr)
COMPOSE_PROJECT_NAME=ustack # Préfixe des conteneurs
```

**GPU:**
```env
GPU_TIER=M                 # S (petit), M (moyen), L (grand)
```

**Modèles:**
```env
LLM_GGUF=your-model.Q4_K_M.gguf  # Fichier GGUF dans data/models/
LLM_CTX=32768                  # Taille de contexte
```

**Sécurité — Mots de passe et clés:**
```env
POSTGRES_PASSWORD=change_me        # Base de données
REDIS_PASSWORD=change_me           # Cache
LITELLM_MASTER_KEY=sk-xxxxxxx      # Clé API LiteLLM
WEBUI_SECRET_KEY=change_me         # Open WebUI
```

**Compte admin Open WebUI:**
```env
WEBUI_ADMIN_EMAIL=admin@entreprise.fr
WEBUI_ADMIN_PASSWORD=min_24_chars_long_password
```

#### Générer les secrets

```bash
bash scripts/gen-secrets.sh
```

### Étape 4: Télécharger les modèles

```bash
./download-models.sh
```

Télécharge les modèles:
- LLM GGUF (configuré via LLM_GGUF)
- Vision mmproj
- Qwen-Image pour ComfyUI
- Modèles Ollama (embeddings, décision)

## Profils de déploiement

### Profils disponibles

| Profil | Services inclus | Usage |
|--------|-----------------|-------|
| `core` | postgres, redis, qdrant, llama, ollama, litellm | Noyau minimal |
| `apps` | open-webui, n8n, searxng, portainer | Applications web |
| `media` | comfyui, whisper, kokoro, docling-serve | Multimédia |
| `vision` | obscura, obscura-mcp | Navigation web |
| `monitoring` | grafana, langfuse, clickhouse | Observabilité |
| `comfyui` | comfyui seul | Génération d'images |

### Lancement par profil

```bash
# Noyau uniquement
./stack --profile core up -d

# Applications uniquement
./stack --profile apps up -d

# Stack complète
./stack up -d

# Combinations
./stack --profile core --profile apps up -d
```

## Gestion de la stack

### Commandes principales

```bash
# Démarrer
./stack up -d

# Arrêter
./stack down

# Redémarrer
./stack restart

# Logs
./stack logs -f

# Logs d'un service
./stack logs -f open-webui

# Statut
./stack ps

# Pull images
./stack pull
```

### Mise à jour de la stack

```bash
# Mettre à jour le dépôt
git pull
git lfs pull

# Mettre à jour les images
./stack pull

# Redémarrer avec les nouvelles images
./stack up -d
```

### Mise à jour des versions

Toutes les versions sont dans `versions.env`. Pour mettre à jour:

1. Modifier les tags dans `versions.env`
2. Exécuter `./stack pull`
3. Exécuter `./stack up -d`

## Tests

```bash
# Vérifier l'intégrité de la stack
./test-stack.sh
```

Vérifie:
- Tous les conteneurs sont démarrés
- Les services répondent
- Les connexions réseau fonctionnent

## URLs de la stack

Une fois déployée, la stack est accessible via:

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
