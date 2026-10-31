# Guide de maintenance

## Sauvegarde

### État actuel

Aucun mécanisme de sauvegarde n'est fourni. Les données sont stockées dans des bind mounts dans le répertoire `data/`.

### Dossiers à sauvegarder

Les données critiques sont dans les dossiers suivants (relatifs à `DATA_DIR`, par défaut `./data`):

| Dossier | Service | Contenu |
|---------|---------|---------|
| `data/postgres` | PostgreSQL | Bases de données n8n, Langfuse, LiteLLM, Open WebUI |
| `data/redis` | Redis | File d'attente n8n, Langfuse, cache LiteLLM |
| `data/qdrant` | Qdrant | Vecteurs pour RAG |
| `data/ollama` | Ollama | Modèles LLM locaux |
| `data/models` | llama-server | Modèles GGUF |
| `data/open-webui` | Open WebUI | Fichiers de l'application (la base est dans Postgres) |
| `data/n8n` | n8n | Workflows et exécutions |
| `data/n8n_shared` | n8n | Fichiers partagés |
| `data/portainer` | Portainer | Configuration Portainer |
| `data/caddy` | Caddy | Certificats TLS |
| `data/comfyui` | ComfyUI | Modèles, output, custom nodes |
| `data/whisper` | Whisper | Cache HuggingFace |
| `data/clickhouse` | ClickHouse | Traces Langfuse |
| `data/s3` | RustFS (S3) | Stockage objets |

`data/postgres` est en mode 700, propriétaire utilisateur interne du conteneur. Une sauvegarde par copie de fichiers exige root et la stack arrêtée. Copier les fichiers d'une base en marche n'est pas cohérent. À prévoir : sauvegarde de Postgres par `pg_dump` ou `pg_dumpall` (non fourni, non testé).

## Monitoring et alertes

### État actuel

Aucun système de monitoring ou d'alerting n'est déployé dans la stack.

### Supervision basique

```bash
# Vérifier l'état des conteneurs
./stack ps

# Consulter les logs d'un service
./stack logs -f service-name

# Tester la stack
./test-stack.sh
```

### GPU

```bash
# Vérifier l'utilisation GPU
nvidia-smi
```

## Logs

### Consulter les logs

```bash
# Logs d'un service spécifique
./stack logs -f open-webui

# Logs de tous les services
./stack logs

# Dernières lignes
./stack logs --tail=100 service-name
```

### Rotation

La rotation des logs est déjà configurée dans `docker-compose.yml` pour les 24 services : driver `json-file`, `max-size` 10 Mo, `max-file` 3.

## Mises à jour

### Mise à jour des versions des images

Les versions sont définies dans `versions.env`:

```bash
# 1. Modifier versions.env avec les nouvelles versions
nano versions.env

# 2. Puller les nouvelles images
./stack pull

# 3. Redéployer
./stack up -d
```

### Mise à jour des configurations

Après modification de `.env`, recréez le conteneur :

```bash
# Modifier la configuration
nano .env

# Recréer le conteneur (recharge les variables d'environnement)
./stack up -d service-name
```

`./stack restart` ne relit pas les variables d'environnement : il redémarre simplement le conteneur avec la même configuration.

### Mise à jour des modèles

```bash
# Télécharger les modèles
./download-models.sh

# Recréer llama-server (recharge les modèles GGUF)
./stack up -d llama-server
```

## Nettoyage

### Images orphelines

```bash
docker image prune -f
```

Attention : `docker image prune` supprime les images inutilisées de tout l'hôte, pas seulement de cette stack.
