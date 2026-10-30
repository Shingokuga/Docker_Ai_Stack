# Outils Open WebUI (MCP)

## Navigateur (Obscura)
**Endpoint:** `http://obscura-mcp:3000/mcp`
**Auth:** Bearer `OBSCURA_MCP_TOKEN`

Outil de navigation web pour Open WebUI :
- Lecture de pages web
- Remplissage de formulaires
- Captures d'écran
- Extraction de contenu (texte, images, PDF)

### Limites
- **Une session de navigation à la fois** (serveur MCP Obscura mono-séance)
- Image officielle sans mode "stealth" (pas d'anonymisation avancée)
- Nécessite une connexion internet fonctionnelle

## Documentation (Context7)
**Endpoint:** `https://mcp.context7.com/mcp`
**Auth:** Bearer `CONTEXT7_API_KEY` (optionnelle)

Recherche et génération de documentation technique :
- Documentation API
- Exemples de code
- Réponses aux questions techniques

### Limites
- Nécessite une clé API gratuite : https://context7.com/dashboard
- Si `CONTEXT7_API_KEY` vide → connexion désactivée (pas d'erreur)
- Nécessite une connexion internet

## Configuration automatique

L'installation configure automatiquement les deux outils via l'API admin d'Open WebUI :

```bash
bash scripts/configure-openwebui.sh
```

Le script :
1. Se connecte à Open WebUI avec les credentials admin
2. Récupère la liste existante des connexions MCP
3. Fusionne (ajoute/mets à jour obscura et context7, garde les autres)
4. Reposte la liste complète

## Connexion manuelle (si besoin)

Dans Open WebUI :

1. Aller à **Admin > Intégrations > Ajouter**
2. Type : **MCP (Streamable HTTP)**
3. Auth : **Bearer**
4. URL : `http://obscura-mcp:3000/mcp`
5. Clé : valeur de `OBSCURA_MCP_TOKEN` depuis `.env`

## Activation dans un chat

Les outils MCP sont réservés aux **admins** dans Open WebUI. Chaque utilisateur les active ensuite dans son chat :

1. Dans la conversation, taper `/tools` ou cliquer sur "Outils"
2. Cocher les outils à activer (Obscura, Context7)
3. Les outils seront disponibles pour le chat