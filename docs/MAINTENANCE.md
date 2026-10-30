# Guide de maintenance

## Sauvegarde

### Stratégie de sauvegarde

La stack utilise **Borg Backup** pour des sauvegardes incrémentales compressées.

### Sauvegarde des données

```bash
# Sauvegarder tous les volumes
./stack backup --type full

# Sauvegarde incrémentale
./stack backup --type incremental

# Restaurer
./stack restore --date 2026-01-01
```

### Sauvegarde des configurations

```bash
# Sauvegarder les fichiers de configuration
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  .env versions.env caddy/ config/
```

### Fréquence recommandée

| Type | Fréquence |
|------|-----------|
| Full | Hebdomadaire |
| Incremental | Quotidienne |
| Config | Avant chaque mise à jour |

## Monitoring et alertes

### Grafana

Accéder aux dashboards à `https://monitoring.{BASE_DOMAIN}`.

### Dashboards principaux

- **Overview**: Vue d'ensemble de la stack
- **LLM**: Utilisation des modèles
- **Services**: Statut des services
- **Infra**: CPU, RAM, disque, réseau

### Alertes

Configurer les alertes dans Grafana:

1. Dashboard → Panneau → Éditer
2. Onglet "Alerting"
3. Définir les conditions et notifications

### Canal de notification

- Slack webhook
- Email
- PagerDuty

## Logs

### Centralisation avec Loki

Tous les logs sont centralisés dans Loki et consultables via Grafana.

### Consulter les logs d'un service

```bash
# Via Docker
./stack logs -f service-name

# Via Loki/Grafana
# Explorec Logs → Filtrer par service
```

### Rotation des logs

La rotation est configurée dans `docker-compose.yml`:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Cela limite chaque fichier de log à 10 Mo et garde 3 fichiers.

## Mises à jour

### Mise à jour des images

```bash
# Pull les nouvelles images
./stack pull

# Redémarrer la stack
./stack down
./stack up -d
```

### Mise à jour des modèles

```bash
# Télécharger les nouveaux modèles
./download-models.sh

# Redémarrer les services concernés
./stack restart llama-server ollama
```

### Mise à jour de la configuration

```bash
# Modifier la configuration
nano .env

# Redémarrer les services concernés
./stack restart
```

## Performance

### Monitoring GPU

```bash
# Via nvidia-smi
nvidia-smi

# Via Grafana dashboard GPU
```

### Optimisation

- **LLM**: Ajuster `LLM_CTX` et le modèle GGUF selon les besoins
- **ComfyUI**: Utiliser `--lowvram` ou `--medvram` si VRAM limitée
- **Redis**: Vérifier `maxmemory-policy noeviction` pour n8n/Langfuse

### Scaling

Pour le scaling, envisager:

- Ajouter plus de conteneurs pour les services stateless
- Scaling horizontal des workers n8n
- Réplication de la base de données

## Sauvegarde et restauration des bases de données

### Postgres

```bash
# Sauvegarde
docker exec postgres pg_dump -U postgres -d n8n > n8n-backup.sql
docker exec postgres pg_dump -U postgres -d langfuse > langfuse-backup.sql

# Restauration
docker exec -i postgres psql -U postgres -d n8n < n8n-backup.sql
```

### Qdrant

```bash
# Sauvegarde
docker exec qdrant qdrant snapshot create all
```

## Nettoyage

### Images Docker

```bash
# Supprimer les images orphelines
docker image prune -f

# Supprimer tous les volumes orphelines
docker volume prune -f
```

### Logs Docker

```bash
# Supprimer les vieux logs
docker system prune --volumes --filter "until=7d"
```
