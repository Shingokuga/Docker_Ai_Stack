# Commandes `./stack`

`./stack` est le point d'entrée unique pour piloter la stack. Il se replace lui-même dans le dossier du dépôt, quel que soit le répertoire courant, puis :

- `./stack doctor` lance le diagnostic décrit ci-dessous ;
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
