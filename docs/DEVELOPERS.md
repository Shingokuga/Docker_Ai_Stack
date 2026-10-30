# Guide développeur

## Ajouter un nouveau service

### 1. Créer la définition de service

Ajouter le service dans `docker-compose.yml`:

```yaml
services:
  mon-service:
    image: nom/ma-image:tag
    restart: unless-stopped
    environment:
      TZ: ${TZ:-Europe/Paris}
    expose:
      - "8080"
    volumes:
      - ${DATA_DIR:-./data}/mon-service:/app/data
    depends_on:
      postgres:
        condition: service_healthy
    networks: [ai_net]
    logging: *default-logging
```

### 2. Configurer Caddy

Ajouter le reverse proxy dans `caddy/Caddyfile`:

```caddy
https://mon-service.{BASE_DOMAIN} {
    reverse_proxy mon-service:8080
}
```

### 3. Créer les répertoires de données

Ajouter dans `install.sh` (fonction `create_data_dirs`):

```bash
# mon-service
$run_as mkdir -p "$DATA_DIR/mon-service"
```

### 4. Ajouter à .env.example

Ajouter les variables d'environnement nécessaires:

```env
# MARK: Mon service
MON_SERVICE_KEY=
MON_SERVICE_SECRET=
```

### 5. Mettre à jour versions.env

```env
IMG_MON_SERVICE=nom/ma-image:tag
```

### 6. Tester

```bash
./stack up -d mon-service
./stack logs -f mon-service
```

## Ajouter un workflow ComfyUI

### 1. Créer le workflow JSON

Créer le fichier dans `comfyui/workflows/`:

```json
{
  "prompt": "Description du workflow",
  "nodes": [
    {
      "class_type": "CheckpointLoaderSimple",
      "inputs": {"ckpt_name": "sd_xl_base.safetensors"},
      "widget_values": null,
      "id": 1,
      "properties": null,
      "title": "Checkpoint Loader"
    },
    {
      "class_type": "EmptyLatentImage",
      "inputs": {
        "width": 1024,
        "height": 1024,
        "batch_size": 1
      },
      "widget_values": null,
      "id": 2,
      "properties": null,
      "title": "Empty Latent"
    },
    {
      "class_type": "KSampler",
      "inputs": {
        "model": ["1", 0],
        "positive": ["3", 0],
        "negative": ["4", 0],
        "latent_image": ["2", 0],
        "steps": 30,
        "cfg": 7,
        "seed": 0,
        "sampler_name": "euler",
        "scheduler": "normal"
      },
      "widget_values": null,
      "id": 5,
      "properties": null,
      "title": "KSampler"
    },
    {
      "class_type": "VAEDecode",
      "inputs": {
        "samples": ["5", 0],
        "vae": ["1", 2]
      },
      "widget_values": null,
      "id": 6,
      "properties": null,
      "title": "VAE Decode"
    },
    {
      "class_type": "SaveImage",
      "inputs": {
        "images": ["6", 0]
      },
      "widget_values": null,
      "id": 7,
      "properties": null,
      "title": "Save Image"
    }
  ],
  "version": 1
}
```

### 2. Tester le workflow

```bash
# Via API
curl -X POST http://comfyui:8188/api/prompt \
  -H "Content-Type: application/json" \
  -d @comfyui/workflows/mon-workflow.json

# Ou charger dans l'interface web
```

## Ajouter un outil MCP

### 1. Créer le serveur MCP

Le serveur doit exposer l'endpoint `/mcp` et suivre le protocole MCP (JSON-RPC).

### 2. Déployer le serveur

Ajouter un conteneur pour votre serveur MCP dans `docker-compose.yml`:

```yaml
services:
  mon-mcp:
    image: mon-image-mcp:tag
    restart: unless-stopped
    expose:
      - "3000"
    networks: [ai_net]
    logging: *default-logging
```

### 3. Configurer Open WebUI

Ajouter la connexion MCP via l'API ou l'interface:

```bash
# Via API Open WebUI
curl -X POST http://open-webui:8080/api/v1/mcp/connections \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mon_outil",
    "type": "http",
    "url": "http://mon-mcp:3000/mcp",
    "auth_type": "bearer",
    "auth_token": "mon_token"
  }'
```

## Convention de nommage

### Services Docker

- Nom court, sans espace
- Hyphens pour les mots multiples
- Pas de majuscules
- Préfixe optionnel pour les groupes: `llm-`, `web-`, `data-`

### Variables d'environnement

- Majuscules avec underscores
- Préfixe par service si nécessaire: `LLM_MODEL`, `WEBUI_SECRET_KEY`

### Répertoires de données

```
data/
├── service-name/
│   └── subdir/
```

### URLs publiques

```
https://nom-service.{BASE_DOMAIN}
```

## Tests et validation

### Tests unitaires

Utiliser Docker pour tester les services individuellement:

```bash
./stack up -d service-name
./stack logs -f service-name
```

### Tests d'intégration

```bash
./stack up -d
./test-stack.sh
```

### Validation de la configuration

```bash
# Vérifier la syntaxe compose
./stack config

# Vérifier la configuration Caddy
docker exec caddy caddy validate
```

## Déploiement

### Build des images

Si vous build une image locale:

```bash
docker build -t mon-service:local .
```

### Push des images

```bash
docker push mon-repository/mon-service:tag
```

### Mise en production

```bash
# Pull les images
./stack pull

# Redémarrer
./stack up -d
```

## Documentation

Chaque nouveau service doit inclure:

1. Entrée dans `docs/API-REFERENCE.md`
2. Section dans `docs/USERS-GUIDE.md`
3. Entrée dans `docs/DEPLOYMENT.md` (si applicable)
4. Entrée dans `docs/TROUBLESHOOTING.md` (si applicable)
5. Entrée dans `docs/MAINTENANCE.md` (si applicable)

## Exemple: Ajouter un service complet

### 1. Créer le service

```dockerfile
# Dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8080
CMD ["python", "app.py"]
```

### 2. Ajouter dans compose

```yaml
services:
  mon-app:
    image: mon-repo/mon-app:latest
    restart: unless-stopped
    environment:
      TZ: ${TZ:-Europe/Paris}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@postgres:5432/mon_app
    expose:
      - "8080"
    depends_on:
      postgres:
        condition: service_healthy
    networks: [ai_net]
    logging: *default-logging
```

### 3. Configurer Caddy

```caddy
https://mon-app.{BASE_DOMAIN} {
    reverse_proxy mon-app:8080
}
```

### 4. Tester

```bash
./stack up -d mon-app
./stack logs -f mon-app
curl http://localhost:8080/health
```

### 5. Documenter

Ajouter dans les fichiers de documentation appropriés.
