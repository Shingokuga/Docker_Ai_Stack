# Guide de dépannage

## Problèmes courants et solutions

### Conteneur ne démarre pas

**Symptôme:** `./stack ps` montre un conteneur en état "Restarting" ou "Exited".

**Solutions:**

```bash
# Vérifier les logs
./stack logs service-name

# Vérifier les dépendances
./stack ps  # Voir quels conteneurs sont démarrés

# Vérifier les ports
docker network ls
docker network inspect ustack_ai_net
```

### Service ne répond pas

**Symptôme:** Page web inaccessible ou timeout.

**Solutions:**

1. Vérifier que le conteneur est démarré
2. Vérifier les logs du service
3. Vérifier la configuration Caddy
4. Tester la connexion interne:

```bash
# Tester la connectivité réseau interne
docker exec caddy curl -s http://service-name:port/health
```

### Erreurs GPU

**Symptôme:** Services GPU (llama-server, comfyui, etc.) échouent.

**Solutions:**

```bash
# Vérifier le GPU
nvidia-smi

# Vérifier le runtime Docker
docker info | grep nvidia

# Redémarrer le runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Erreurs de mémoire

**Symptôme:** Conteneurs tués (OOM), lenteurs extrêmes.

**Solutions:**

1. Vérifier l'usage mémoire:
```bash
./stack stats
```

2. Augmenter les limites dans `docker-compose.yml` si nécessaire
3. Vérifier que les modèles ne dépassent pas la RAM disponible

### Erreurs de stockage

**Symptôme:** Erreurs de disque plein, fichiers non écrits.

**Solutions:**

```bash
# Vérifier l'espace disque
df -h

# Vérifier les volumes (bind mounts sous data/)
du -sh data/* 2>/dev/null
# Note: certains dossiers (data/postgres) sont illisibles sans root
```

### Erreurs réseau

**Symptôme:** Services ne communiquent pas entre eux.

**Solutions:**

```bash
# Vérifier le réseau
docker network ls
docker network inspect ustack_ai_net

# Tester la connectivité
docker exec container1 ping container2
```

## Logs à consulter

| Problème | Service | Commande |
|----------|---------|----------|
| Erreur LLM | llama-server | `./stack logs -f llama-server` |
| Erreur chat | open-webui | `./stack logs -f open-webui` |
| Erreur API | litellm | `./stack logs -f litellm` |
| Erreur GPU | tous GPU | `nvidia-smi` |
| Erreur réseau | caddy | `./stack logs -f caddy` |
| Erreur base | postgres | `./stack logs -f postgres` |
| Erreur cache | redis | `./stack logs -f redis` |
| Erreur workflow | n8n | `./stack logs -f n8n` |

## Tests de diagnostic

### Test de la stack complète

```bash
./test-stack.sh
```

Ce script vérifie pour chaque hôte listé dans caddy/hostnames.txt:
- Un curl -fsS avec un timeout de 5 s sur la page d'accueil en HTTPS
- Le certificat interne est accepté (hôte : /root.crt en HTTP)
- Affiche le Total, OK et Échecs des tests
- Code de sortie 1 s'il y a au moins un échec
Il ne vérifie pas l'état des conteneurs.

### Tests individuels

```bash
# Tester le LLM
  -H "Authorization: Bearer sk-xxxx" \
  -d '{"model":"chat","messages":[{"role":"user","content":"test"}]}'

# Tester le GPU
nvidia-smi

# Tester les ports (uniquement caddy publie des ports)
./test-stack.sh
```

## Problèmes spécifiques aux services

### Open WebUI

**Problème:** Impossible de se connecter.
**Solution:** Vérifier `WEBUI_ADMIN_EMAIL` et `WEBUI_ADMIN_PASSWORD` dans `.env`.

**Problème:** Outils MCP non disponibles.
**Solution:**
```bash
./stack restart obscura obscura-mcp
bash scripts/configure-openwebui.sh
```

### ComfyUI

**Problème:** VRAM insuffisante.
**Solution:** Ajouter `--lowvram` à la fin de la valeur de COMFYUI_START_COMMAND dans docker-compose.yml (service comfyui), puis `./stack up -d comfyui`.

**Problème:** Modèles non chargés.
**Solution:**
```bash
./download-models.sh
./stack restart comfyui
```

### Whisper/Kokoro

**Problème:** Transcription/synthèse lente.
**Solution:** Vérifier l'usage GPU. Le modèle doit être sur GPU.

**Problème:** Erreurs de format audio.
**Solution:** Vérifier le format du fichier (mp3, wav, etc.).

### N8N

**Problème:** Workflows non exécutés.
**Solution:** Vérifier que `n8n-worker` est démarré.

**Problème:** Erreurs de connection externe.
**Solution:** Vérifier la connectivité réseau du conteneur.

## Contact support

Si le problème persiste:

1. Consulter les logs complets
2. Vérifier la documentation
3. Contacter l'équipe technique de KM Consult
4. Ouvrir une issue sur le dépôt GitHub
