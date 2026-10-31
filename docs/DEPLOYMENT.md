# Guide de déploiement

## Prérequis système

| Ressource | Minimum | Recommandé | Notes |
|-----------|---------|------------|-------|
| OS | Ubuntu 22.04 LTS / 24.04 LTS | Ubuntu 24.04 LTS | Utilisateur avec sudo |
| GPU NVIDIA | — | GPU NVIDIA | Optionnel |
| Pilote NVIDIA | — | ≥ 570 | Images cu128 ; avertissement si < 570 |
| Disque SSD | ~25 Go | 500 Go+ | Voir détails ci-dessous |
| Mémoire vive | Non mesurée | Non mesurée | Non testée |

### Disque (mesuré le 31/10, taille des fichiers)

| Palier | GGUF + mmproj | ComfyUI (optionnel) | Total estimé |
|--------|---------------|---------------------|--------------|
| L | 19,4 Go | +41,3 Go | ~20 Go ou ~61 Go |
| M / S | 7,9 Go | +41,3 Go | ~8 Go ou ~49 Go |

Au premier démarrage, ollama-init télécharge embeddinggemma-2 (1,3 Go) et kev:9b-q4_K_M (5,6 Go), et le service whisper télécharge large-v3 (3,1 Go). Les poids des images Docker n'ont pas été mesurés.

### Paliers GPU

Le palier détermine le modèle GGUF chargé. Détection automatique basée sur la mémoire GPU (`nvidia-smi`) :

| Palier | Condition | Modèle |
|--------|-----------|--------|
| L | ≥ 24 Go VRAM | Qwen3.8-27B |
| M | ≥ 8 Go VRAM | Qwen3.5-9B |
| S | < 8 Go VRAM ou sans GPU | Qwen3.5-9B |

Si `nvidia-smi` indique [N/A] pour la VRAM (mémoire unifiée), la mémoire système est utilisée. Sans `nvidia-smi`, palier S.

---

## Étape 1 : Bootstrap

`bootstrap.sh` prépare une machine vierge :

- `apt update` + `apt upgrade` complet ; si un redémarrage est requis, il s'arrête et indique la commande à relancer
- Installation de git, git-lfs, curl, ca-certificates, jq
- Installation de Docker depuis le dépôt docker.com
- Si `nvidia-smi` existe : avertissement si pilote < 570, installation de nvidia-container-toolkit, configuration du runtime Docker (redémarrage de Docker uniquement si le runtime n'était pas configuré)
- Ajout de l'utilisateur au groupe docker
- Clone ou mise à jour du dépôt
- Lancement de `install.sh` avec les arguments transmis

### Variables d'environnement de bootstrap.sh

| Variable | Défaut | Usage |
|----------|--------|-------|
| `STACK_REPO_URL` | `https://github.com/Shingokuga/Docker_Ai_Stack.git` | URL du dépôt |
| `STACK_BRANCH` | `main` | Branche à cloner |
| `STACK_DIR` | `$HOME/Docker_Ai_Stack` | Répertoire de destination |
| `GITHUB_TOKEN` | — | Dépôt privé (voir ci-dessous) |
| `BOOTSTRAP_YES` | — | Si `=1`, mode non interactif |

```bash
# Machine vierge, dépôt public
bash bootstrap.sh

# Mode non interactif, sans GPU
bash bootstrap.sh --yes --no-gpu

# Dépôt privé
export GITHUB_TOKEN="ghp_xxx"
STACK_REPO_URL=https://github.com/org/private-stack.git bash bootstrap.sh
```

### Dépôt privé avec GITHUB_TOKEN

Le jeton est envoyé en en-tête HTTP Authorization, jamais dans l'URL. Le dépôt ne contient aucun fichier LFS. Le jeton doit avoir un accès en lecture seule sur le dépôt (fine-grained recommandé). La procédure détaillée se trouve dans l'en-tête de `bootstrap.sh`.

---

## Étape 2 : install.sh

`install.sh` configure et lance la stack.

### Options

| Option | Effet |
|--------|-------|
| `--yes` | Mode non interactif (utilise les variables d'environnement) |
| `--no-gpu` | Palier S, aucun modèle GGUF téléchargé, seuls les 17 services sans GPU démarrent |
| `--config-only` | Crée/mise à jour `.env`, génère les secrets, valide la configuration compose, mais ne télécharge ni ne démarre |

### Ordre d'exécution

1. Vérification des prérequis (docker, compose v2, groupe docker)
2. Questions interactives (domaine, e-mail admin, ComfyUI, palier GPU)
3. Création ou mise à jour de `.env` (copie de `.env.example` si absent)
4. Choix des modèles selon le palier
5. Génération des secrets
6. Récapitulatif et confirmation
7. Validation de la configuration compose (`--config-only` s'arrête ici)
8. Téléchargement des modèles
9. Création des répertoires `data/`
10. Pull et démarrage des services
11. Attente de Open WebUI (300 s par défaut, configurable via `WEBUI_WAIT_SECONDS`)
12. Configuration de Open WebUI (outils MCP)
13. Récapitulatif des adresses

### Mode --yes (variables d'environnement)

En mode `--yes`, les valeurs sont lues dans cet ordre de priorité :

| Paramètre | Variable d'env | .env | Défaut si absent |
|-----------|----------------|------|-----------------|
| Domaine | `BASE_DOMAIN` | `BASE_DOMAIN` | `local` |
| E-mail admin | `ADMIN_EMAIL` | `WEBUI_ADMIN_EMAIL` | `admin@<domaine>` |
| ComfyUI | `ENABLE_COMFYUI` (1/0) | `COMPOSE_PROFILES=comfyui` | non activé |
| Palier GPU | `GPU_TIER` | `GPU_TIER` | détection automatique |

```bash
# Déploiement non interactif complet
BASE_DOMAIN=ai.entreprise.fr ADMIN_EMAIL=admin@entreprise.fr GPU_TIER=L \
ENABLE_COMFYUI=1 bash install.sh --yes

# Configuration seule, sans téléchargement ni démarrage
bash install.sh --config-only

# Sans GPU (17 services, pas de modèle GGUF)
bash install.sh --yes --no-gpu
```

### Services sans GPU (--no-gpu)

Les 6 services GPU suivants ne démarrent pas avec `--no-gpu` : comfyui, docling-serve, kokoro, llama-server, ollama, whisper. Les 17 autres services fonctionnent sans GPU.

---

## Profil comfyui

Le seul profil compose est `comfyui`. Il n'est pas inclus dans un `up -d` standard.

### Activation

```bash
# Via .env (recommandé)
echo 'COMPOSE_PROFILES=comfyui' >> .env
./stack up -d

# Via ligne de commande
./stack --profile comfyui up -d
```

### Comportement mesuré

- `up -d` sans profil : ne démarre pas les services à profil
- `--profile comfyui` : ajoute les services comfyui aux autres services
- `down` : arrête et supprime tous les services du projet (tous profils)
- `stop <service>` : n'arrête que le service spécifié

### Services GPU du profil comfyui

Le service `comfyui` (5 fichiers, ~41,3 Go) est le seul service supplémentaire du profil. Les 5 autres services GPU (docling-serve, kokoro, llama-server, ollama, whisper) font partie de la stack principale et ne nécessitent pas de profil.

---

## Gestion de la stack

`./stack` est un wrapper autour de `docker compose` utilisant les fichiers `versions.env` et `.env`.

### Commandes principales

```bash
# Démarrer
./stack up -d

# Démarrer un service spécifique
./stack up -d open-webui

# Redémarrer un service (relit .env)
./stack up -d <service>

# Arrêter un service
./stack stop <service>

# Arrêter tout le projet
./stack down

# Logs
./stack logs -f
./stack logs -f open-webui

# Statut des conteneurs
./stack ps

# Pull des nouvelles images
./stack pull
```

### Note sur restart vs up

`./stack restart` ne relit pas `.env` (mesuré). Pour appliquer une modification de `.env`, utiliser `./stack up -d <service>`.

---

## Mise à jour

Le dépôt ne contient aucun fichier LFS.

### Mise à jour de la stack

```bash
# 1. Mettre à jour le dépôt
git pull

# 2. Modifier les versions si nécessaire
nano versions.env

# 3. Pull des nouvelles images
./stack pull

# 4. Redéployer
./stack up -d
```

### Mise à jour d'un seul service

```bash
./stack pull <service>
./stack up -d <service>
```

### Modification de .env

```bash
nano .env
./stack up -d  # Applique à tous les services
```

---

## Tests

### test-stack.sh

Pour chaque hôte défini dans `caddy/hostnames.txt`, `test-stack.sh` effectue une requête HTTPS de 5 secondes (certificat interne accepté ; l'hôte `certificat` est testé en HTTP sur `/root.crt`). Le script retourne le code 1 s'au moins un hôte échoue.

```bash
./test-stack.sh
```

### Vérification des conteneurs

`test-stack.sh` ne teste pas l'état des conteneurs. Pour cela :

```bash
./stack ps
```

### Hôtes testés

chat-ai, automatisation, suivi-ia, admin, documents, api, stockage, certificat, images (si profil comfyui).

---

## Adresses

| Service | URL |
|---------|-----|
| Chat IA | `https://chat-ai.<BASE_DOMAIN>` |
| Automatisation | `https://automatisation.<BASE_DOMAIN>` |
| Suivi IA | `https://suivi-ia.<BASE_DOMAIN>` |
| Admin | `https://admin.<BASE_DOMAIN>` |
| Documents | `https://documents.<BASE_DOMAIN>` |
| API | `https://api.<BASE_DOMAIN>` |
| Stockage | `https://stockage.<BASE_DOMAIN>` |
| Certificat | `https://certificat.<BASE_DOMAIN>` |
| Images (ComfyUI) | `https://images.<BASE_DOMAIN>` |

---

## Scripts annexes

### Téléchargement des modèles seul

`./download-models.sh` peut être utilisé seul pour télécharger les modèles sans redéployer la stack.

### Génération des secrets

Les secrets sont générés automatiquement par `install.sh`. Le script `scripts/gen-secrets.sh` peut être utilisé pour les régénérer.

### Vérification de la cohérence

Le script `scripts/stack-consistency-check.py` vérifie la cohérence entre les versions dans `versions.env`, les tags dans les fichiers compose, et les documents.

```bash
python3 scripts/stack-consistency-check.py
```
