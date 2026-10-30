# Profil ComfyUI — Génération d'images

## Description

Le profil `comfyui` déploie [ComfyUI](https://github.com/comfyanonymous/ComfyUI) via l'image communautaire `yanwk/comfyui-boot:nightly`, pré-installée avec les dépendances GPU, les custom nodes et l'interface workflow. Les modèles sont fournis via le volume `/models` (téléchargés par `download-models.sh`).

## Lancement

```bash
# Lancer uniquement ComfyUI
./stack --profile comfyui up -d

# Lancer la stack complète + ComfyUI
./stack up -d
```

## Modèles

Les modèles Qwen-Image 2.1 sont téléchargés automatiquement par `download-models.sh` :

- **Diffusion model (BF16)**: `qwen_image_2.1_bf16.safetensors` → `/models/diffusion_models/`
- **VAE**: `sdxl_vae.safetensors` → `/models/vae/`
- **Text encoder**: `qwen2_5_7b_fp16.safetensors` → `/models/text_encoders/`

Pour re-télécharger ou vérifier :

```bash
./download-models.sh
```

## Workflows

Les workflows fournis sont dans `comfyui/workflows/` :

- `text-to-image.json` — Génération d'image à partir de texte
- `image-to-image.json` — Modification d'image existante

Importez-les dans l'interface ComfyUI via `Load` ou utilisez l'API `/api/prompt`.

## API

ComfyUI expose une API REST complète sur `http://comfyui:8188` (interne uniquement, accessible via Caddy à `https://images.${BASE_DOMAIN}`) :

- `GET /api/system_stats` — Statistiques système et VRAM
- `POST /api/prompt` — Soumettre un workflow
- `GET /api/queue` — Statut de la file d'attente
- `GET /api/history` — Historique des générations

Exemple d'appel API :

```bash
# Soumettre un workflow
curl -X POST http://comfyui:8188/api/prompt \
  -H "Content-Type: application/json" \
  -d @comfyui/workflows/text-to-image.json

# Vérifier le statut
curl -s http://comfyui:8188/api/queue | jq .
```

## Stockage des outputs

Les images générées sont stockées dans `data/comfyui/output/` et accessibles via Caddy à `https://images.${BASE_DOMAIN}/output/`.

## Custom nodes

Les custom nodes sont installés dans `data/comfyui/custom_nodes/`. Pour ajouter un custom node :

```bash
# Exemple : installer un custom node depuis GitHub
docker exec comfyui git clone https://github.com/user/custom-node /comfyui/custom_nodes/custom-node
docker restart comfyui
```

## Logs

```bash
./stack logs -f comfyui
```

## Dépannage

### VRAM insuffisante

Si vous rencontrez des erreurs de mémoire VRAM, ajoutez `--lowvram` ou `--medvram` à `COMFYUI_START_COMMAND` dans `docker-compose.yml` :

```yaml
COMFYUI_START_COMMAND: "python /comfyui/main.py --listen 0.0.0.0 --port 8188 --lowvram"
```

### Erreurs de dépendances

Si les custom nodes ont des problèmes de dépendances :

```bash
docker exec comfyui pip install <package>
```

## Arrêt

```bash
# Arrêter uniquement ComfyUI
./stack --profile comfyui down

# Arrêter toute la stack
./stack down
```