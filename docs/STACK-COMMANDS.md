# Commandes `./stack`

`./stack` est le point d'entrée unique pour piloter la stack. Il se replace lui-même dans le dossier du dépôt, quel que soit le répertoire courant, puis :

- `./stack doctor` lance le diagnostic décrit ci-dessous ;
- `./stack versions` affiche les versions déclarées et les conteneurs en cours ;
- `./stack update [service...]` met à jour les images des services, avec rollback automatique ;
- toute autre commande est transmise telle quelle à Docker Compose, avec les deux fichiers d'environnement du dépôt :

  ```bash
  docker compose --env-file versions.env --env-file .env <arguments>
  ```

  Exemples : `./stack config -q`, `./stack ps -a`, `./stack logs -f`, `./stack --profile comfyui config --format json`.

## ./stack doctor

### But

Vérifier en quelques secondes qu'une installation est saine, sans rien modifier. Le diagnostic regarde l'outillage (Docker, Compose), les fichiers de configuration (`docker-compose.yml`, `.env`, `versions.env`), puis l'état réel de la stack : ports publiés, images des conteneurs en cours, santé des conteneurs et certificat TLS de Caddy.

Il s'applique au projet Compose défini par `COMPOSE_PROJECT_NAME` (dans `.env`) : « tenu par la stack » désigne les conteneurs de ce projet.

```bash
./stack doctor
echo $?   # 0 = aucun problème critique, 1 = au moins un ❌
```

### Format de sortie

Chaque contrôle commence par une ligne `🔍 <titre>`, suivie d'une ou plusieurs lignes indentées qui commencent par un symbole de gravité :

| Symbole | Signification | Compté dans le récapitulatif |
|---------|---------------|------------------------------|
| ✅ | contrôle réussi | `OK` |
| ⚠️ | avertissement : à examiner, ne bloque pas | `Warnings` |
| ❌ | problème critique : à corriger avant de déployer | `Critical` |
| ℹ️ | information (rien à comparer, contrôle impossible) | non compté |

Le récapitulatif final (`📊 Summary`) donne les trois compteurs.

### Contrôles et gravité

| Contrôle (titre affiché) | ✅ quand | ⚠️ avertissement | ❌ critique |
|--------------------------|----------|------------------|-------------|
| `Docker installation` | `docker` est dans le `PATH` | | `docker` absent |
| `Docker Compose installation` | `docker compose version` répond (ou `docker-compose` présent) | | aucun des deux |
| `docker-compose.yml validation` | `config -q` sort 0, avec les mêmes fichiers d'environnement que `./stack config -q` | | `config -q` échoue : la première ligne d'erreur est affichée |
| `.env file and required variables` | `.env` présent et toutes les variables de `.env.example` y figurent | variables manquantes | `.env` absent |
| `versions.env file` | fichier présent | | fichier absent |
| `Docker image versions` | toutes les images en cours sont celles que Compose résout | une image en cours diffère (les deux valeurs sont affichées) | |
| `Port availability` | port libre, ou tenu par la stack | port occupé par un autre processus | jamais |
| `Volume directories` | `data/` existe | `data/` absent (créé au premier démarrage) | |
| `Container health` | aucun conteneur `unhealthy` | | au moins un conteneur `unhealthy` |
| `SSL certificates` | `Caddyfile` présent et certificat racine valide plus de 30 jours | `Caddyfile` absent ; caddy arrêté (certificat non vérifié) ; certificat qui expire dans moins de 30 jours ; certificat illisible | certificat racine local déjà expiré |
| `Secret tokens` | `OBSCURA_CDP_TOKEN` et `OBSCURA_MCP_TOKEN` renseignés | jeton absent ou vide | |

Quand une information indispensable manque (Docker injoignable, `.env` absent, `docker-compose.yml` invalide, ni `jq` ni `python3`), les contrôles qui en dépendent affichent un ℹ️ avec la raison au lieu d'un ✅ : rien n'est déclaré sain sans avoir été vérifié.

### Détail des contrôles qui lisent l'état de la stack

**Compose.** `config -q` est lancé avec `--env-file versions.env --env-file .env`, comme le passe-plat. Sans `.env`, seule la syntaxe YAML est vérifiée (ℹ️ si PyYAML est absent).

**Ports.** Les ports publiés sont lus dans `config --format json` (avec `jq`, ou `python3` si `jq` est absent) ; les plages sont développées et les protocoles tcp/udp distingués. Pour chaque port :

- libre : ✅ `port N libre (requis par <service>)` ;
- tenu par un conteneur en cours de ce projet : ✅ `port N tenu par la stack (<service>)` ;
- tenu par autre chose : ⚠️ `port N occupé par un autre processus (requis par <service>)`, jamais ❌.

Un port UDP est noté `N/udp`. L'écoute est testée avec `ss` (à défaut `netstat`), sans privilège particulier ; le nom du processus occupant n'est pas affiché. Sans `ss` ni `netstat`, chaque port est signalé en ℹ️ « état indéterminé ».

**Images.** Pour chaque conteneur en cours (`ps --format json`, champ `Image`), l'image est comparée à celle que Compose résout pour le service (`config --format json`, donc `versions.env`). Une différence donne un ⚠️ avec les deux valeurs. Sans conteneur : ℹ️ `aucun conteneur, pas de comparaison`. Les conteneurs dont le service n'a pas d'image dans la configuration (profil non activé, image construite localement) sont signalés en ℹ️ et ne sont pas comparés. Le ✅ n'apparaît que si au moins une image a été comparée et que toutes sont conformes.

**Santé des conteneurs.** Le champ `Health` de `ps --format json` est lu : un conteneur `unhealthy` donne un ❌ avec le nom des services concernés. Sans conteneur en cours : ℹ️ `No containers running (stack is down)`.

**SSL.** Le `Caddyfile` doit exister. Si caddy tourne, le certificat racine de l'autorité locale est lu en lecture seule dans le conteneur, puis son expiration est testée avec `openssl` :

```bash
docker compose --env-file versions.env --env-file .env exec -T caddy cat /data/caddy/pki/authorities/local/root.crt | openssl x509 -noout -checkend 2592000
```

(2 592 000 secondes = 30 jours.)

- valide plus de 30 jours : ✅ (la date d'expiration est affichée) ;
- expire dans moins de 30 jours : ⚠️ ;
- déjà expiré : ❌ ;
- caddy arrêté : ⚠️ `caddy arrêté, certificat non vérifié`, jamais ❌ ;
- certificat illisible ou `openssl` absent : ⚠️, certificat non vérifié.

### Exemple

Extrait d'une exécution avec la stack arrêtée et le port 80 tenu par un autre processus :

```text
🔍 Docker image versions
  ℹ️  aucun conteneur, pas de comparaison
🔍 Port availability
  ⚠️  port 80 occupé par un autre processus (requis par caddy)
  ✅ port 443 libre (requis par caddy)
🔍 SSL certificates
  ✅ Caddyfile exists
  ⚠️  caddy arrêté, certificat non vérifié
```

### Codes retour

| Code | Condition |
|------|-----------|
| `0` | aucun ❌ (les ⚠️ et les ℹ️ n'ont pas d'effet sur le code) |
| `1` | au moins un ❌ |

### Prérequis des contrôles

- `jq`, ou `python3` à défaut, pour lire les sorties JSON de Compose ;
- `ss`, ou `netstat` à défaut, pour les ports ;
- `openssl` pour le certificat.

Si l'un d'eux manque, le contrôle concerné affiche un ℹ️ ou un ⚠️ « non vérifié », jamais un ❌.

### Lecture seule

Le diagnostic n'exécute que `docker --version`, `docker compose version`, `config`, `ps` et la lecture du certificat dans le conteneur caddy. Il ne télécharge rien, ne démarre, n'arrête et ne supprime aucun conteneur, n'écrit aucun fichier et n'utilise pas `sudo` : il peut être lancé à tout moment, y compris sur une stack en service.

## ./stack versions

### But

Afficher en une commande la version de chaque image déclarée dans `versions.env`, puis l'état réel des conteneurs (image en cours, état, santé). La commande ne modifie rien.

### Usage

```bash
./stack versions
echo $?   # 0
```

### Sortie

Deux blocs :

1. **les versions déclarées** — une ligne par variable de `versions.env` (`IMG_POSTGRES`, `IMG_REDIS`, …), au format `variable  valeur` ;
2. **les conteneurs** — un tableau `SERVICE / IMAGE / ETAT / SANTE` construit à partir de `docker compose ps -a --format json`.

Si la stack n'est pas démarrée, un message l'indique clairement (« aucun conteneur : la stack n'est pas démarrée ») et la commande se termine quand même avec le code 0 : ce n'est pas une erreur.

Si Docker est absent du `PATH`, seul le premier bloc est affiché et l'indisponibilité des conteneurs est signalée.

### Codes retour

| Code | Condition |
|------|-----------|
| `0` | versions affichées (stack arrêtée comprise) |
| `1` | `versions.env` introuvable dans le dépôt |

## ./stack update

### But

Mettre à jour **réellement** les images de la stack : recherche d'une version plus récente dans le registre, écriture dans `versions.env`, téléchargement de l'image, recréation des conteneurs, puis test de santé. Si le test de santé échoue, la mise à jour est annulée : `versions.env` est restauré et les conteneurs repartent avec les versions précédentes.

### Usage

```bash
./stack update                      # tous les services
./stack update postgres redis       # seulement ceux-là
./stack update --dry-run            # simulation : aucune écriture
./stack update --same-major-only    # pas de changement de version majeure
./stack update --help
```

### Les cinq étapes

| Étape | Action |
|-------|--------|
| 1/5 | sauvegarde de `versions.env` (copie `versions.env.snapshot` dans un répertoire temporaire, chemin affiché) |
| 2/5 | recherche d'une version plus récente, écriture de la nouvelle valeur dans `versions.env`, `docker compose pull` |
| 3/5 | recréation des conteneurs concernés (`docker compose up -d <services>`) |
| 4/5 | test de santé (`./test-stack.sh`) |
| 5/5 | suppression de la sauvegarde — **uniquement si le test de santé est réussi** |

Pour chaque service traité, la version avant et la version après sont affichées :

```text
    • postgres (IMG_POSTGRES) : postgres:17.11 → postgres:18.0
```

### Recherche d'une version plus récente

- Les tags publiés sont lus via l'API OCI du registre (Docker Hub, GHCR, docker.n8n.io, docker.langfuse.com…), en accès anonyme : aucun identifiant n'est stocké ni requis.
- Un candidat n'est retenu que s'il a **exactement la même forme** que le tag courant (mêmes suites de caractères, même nombre de composantes) et un numéro supérieur : `17.11` → `17.12` ou `18.0`, `v0.9.1-cu128` → `v0.9.2-cu128`. Un tag flottant (`latest`) ou d'une autre série n'est jamais proposé : les tags restent épinglés.
- Une version de la **même série majeure** est préférée ; si aucune n'existe, la version majeure la plus haute est retenue et le changement est signalé (`⚠️ version majeure (17 → 18)`). L'option `--same-major-only` interdit ce changement : la mise à jour ne porte alors que sur la série majeure courante. Dans tous les cas, le test de santé tranche et le rollback annule une mise à jour incompatible.
- Si aucune version plus récente n'est vérifiable (registre injoignable, image épinglée par digest), le service est signalé (« aucune version plus récente vérifiable ») et laissé intact : la mise à jour continue pour les autres.
- `--dry-run` affiche les versions trouvées sans rien modifier.

### Services acceptés et couverture

Le script contient la table complète service Compose → variable `IMG_` de `versions.env`. Les 20 variables `IMG_*` de `versions.env` y sont couvertes, y compris `IMG_S3_INIT` (service `s3-init`) et `IMG_LANGFUSE_WEB` / `IMG_LANGFUSE_WORKER`.

- Un nom de service hors table est **refusé** avec la liste des services acceptés (code 2) : rien n'est ignoré en silence.
- Une variable `IMG_*` présente dans `versions.env` mais absente de la table fait échouer la mise à jour (code 2) : il faut compléter la table du script.
- Un service dont l'image n'est pas pilotée par `versions.env` (par exemple `comfyui`, image construite localement) est signalé et laissé intact.

### Rollback

En cas d'échec du test de santé (ou du pull, ou de la recréation) :

1. `versions.env` est restauré depuis la sauvegarde ;
2. les conteneurs concernés sont recréés avec les versions précédentes ;
3. le message l'annonce explicitement (« mise à jour annulée : versions.env restauré ») ;
4. la commande se termine avec le code **1**.

La sauvegarde **n'est pas supprimée** dans ce cas : son chemin est affiché, elle est conservée pour l'analyse. Elle n'est supprimée qu'après un test de santé réussi.

### Codes retour

| Code | Condition |
|------|-----------|
| `0` | mise à jour appliquée et test de santé réussi, ou aucune version plus récente à appliquer |
| `1` | mise à jour échouée et annulée (test de santé, pull ou recréation en échec) — rollback effectué |
| `2` | erreur d'usage : service inconnu, option inconnue, `versions.env` absent, ou variable `IMG_*` non couverte par la table |

### Options

| Option | Effet |
|--------|-------|
| `--dry-run` | affiche les versions trouvées, n'écrit rien |
| `--same-major-only` | ne propose que des versions de la série majeure courante |
| `-h`, `--help` | aide de la commande |

### Prérequis

- `docker` et `docker compose` ;
- `curl` pour interroger les registres ;
- `jq`, ou `python3` à défaut, pour lire les sorties JSON de Compose.

Aucune valeur secrète n'est écrite, aucun privilège `sudo` n'est utilisé et aucun tag flottant n'est introduit.
