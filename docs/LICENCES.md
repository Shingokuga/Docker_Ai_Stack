# Inventaire des licences — Stack universelle

Vérifié le 2026-11-02 : licences des dépôts GitHub avec `gh api repos/<propriétaire>/<dépôt>/license -f ref=<ref épinglée>` (champ spdx_id), licences des modèles avec `curl -s https://huggingface.co/api/models/<dépôt>` (champs license, license_name, base_model), tags d'images avec `docker manifest inspect` (linux/amd64, vérifiés le 2026-11-01).

**⚠️ Qwen-Image 2.1 et ses copies Comfy-Org/Qwen-Image-2.1 et abenzerps/Qwen-Image-2.1-Uncensored-Quantized, téléchargées par `download-models.sh`, sont déclarées `other / qwen-research` ; le texte de la licence contient « FOR NON-COMMERCIAL PURPOSES ONLY ». Voir la section « Restrictions d'usage commercial ».**

Les licences sont lues à la ref épinglée dans `versions.env`, `docker-compose.yml` ou `Dockerfile.comfyui`. Quand GitHub renvoie NOASSERTION, la cellule Licence donne le nom de la licence personnalisée et le lien pointe vers l'URL brute du texte.

## Composants de la stack

| Composant | Version | Licence | Lien | Obligation pour intégrateur |
|-----------|---------|---------|------|----------------------------|
| PostgreSQL | 17.11 | PostgreSQL License (texte du fichier COPYRIGHT ; gh api : NOASSERTION) | [COPYRIGHT](https://raw.githubusercontent.com/postgres/postgres/REL_17_11/COPYRIGHT) | Aucune restriction d'usage commercial |
| Redis | 7.4.12 | Redis Source Available License v2 (RSALv2) ou Server Side Public License v1 (SSPLv1), au choix ; gh api : NOASSERTION | [LICENSE.txt](https://raw.githubusercontent.com/redis/redis/7.4.12/LICENSE.txt) | Voir Q3 (RSALv2 et SSPLv1 : restrictions de mise à disposition comme service) |
| Qdrant | v1.20.0 | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/qdrant/qdrant/v1.20.0/LICENSE) | Aucune restriction d'usage commercial |
| Ollama | 0.40.13 | MIT | [LICENSE](https://raw.githubusercontent.com/ollama/ollama/v0.40.13/LICENSE) | Aucune restriction d'usage commercial |
| llama.cpp | server-cuda-b11206 | MIT | [LICENSE](https://raw.githubusercontent.com/ggml-org/llama.cpp/b11206/LICENSE) | Aucune restriction d'usage commercial |
| LiteLLM | v1.106.6 | MIT hors répertoire enterprise/ (BerriAI Enterprise license, enterprise/LICENSE.md) ; gh api : NOASSERTION | [LICENSE](https://raw.githubusercontent.com/BerriAI/litellm/v1.106.6/LICENSE) | Voir Obligations détaillées (répertoire enterprise/) |
| Open WebUI | v0.12.5 | Open WebUI License : BSD-3-Clause (clause marque) ; gh api : NOASSERTION | [LICENSE](https://raw.githubusercontent.com/open-webui/open-webui/v0.12.5/LICENSE) | Voir clause marque (50 utilisateurs), Q2 |
| n8n | 2.45.6 | Sustainable Use License 1.0, fichiers .ee. sous n8n Enterprise License (LICENSE_EE.md) ; gh api : NOASSERTION | [LICENSE.md](https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md) | Distribution gratuite et non commerciale uniquement (voir Q1) |
| Docling | v1.38.2 | MIT | [LICENSE (docling-serve)](https://raw.githubusercontent.com/docling-project/docling-serve/v1.38.2/LICENSE) | Aucune restriction d'usage commercial |
| Kokoro-FastAPI | v0.9.1 | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/remsky/Kokoro-FastAPI/v0.9.1/LICENSE) | Aucune restriction d'usage commercial |
| Speaches | 0.8.3 | MIT | [LICENSE](https://raw.githubusercontent.com/speaches-ai/speaches/v0.8.3/LICENSE) | Aucune restriction d'usage commercial |
| ClickHouse | 25.12.11.4 | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/ClickHouse/ClickHouse/v25.12.11.4-stable/LICENSE) | Aucune restriction d'usage commercial |
| RustFS | 1.0.4 | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/rustfs/rustfs/1.0.4/LICENSE) | Aucune restriction d'usage commercial |
| aws-cli | 2.39.2 | Apache License, Version 2.0 (notice en tête du fichier LICENSE.txt) ; gh api : NOASSERTION | [LICENSE.txt](https://raw.githubusercontent.com/aws/aws-cli/2.39.2/LICENSE.txt) | Aucune restriction d'usage commercial |
| Langfuse | 4.72.0 | MIT Expat hors répertoires ee/ (Langfuse Enterprise license, ee/LICENSE) ; gh api : NOASSERTION | [LICENSE](https://raw.githubusercontent.com/langfuse/langfuse/v4.72.0/LICENSE) | Voir Obligations détaillées (répertoires ee/) |
| SearXNG | 2026.10.30 | AGPL-3.0 | [LICENSE](https://raw.githubusercontent.com/searxng/searxng/1cd13d98d65a58f1126fa5bb5c77e42c0ea625f3/LICENSE) | Voir obligations AGPL (Q4) |
| Portainer CE | 2.45.3 | Zlib | [LICENSE](https://raw.githubusercontent.com/portainer/portainer/2.45.3/LICENSE) | Trois restrictions dans le texte Zlib (voir Obligations détaillées) |
| Caddy | 2.11.7 | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/caddyserver/caddy/v2.11.7/LICENSE) | Aucune restriction d'usage commercial |
| Obscura | 0.2.5 | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/h4ckf0r0day/obscura/v0.2.5/LICENSE) | Aucune restriction d'usage commercial (voir Q5) |
| ComfyUI | nightly-20261030 | GPL-3.0 | [LICENSE](https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE) | Voir obligations GPL (Q4) |
| ComfyUI-Docker (image yanwk/comfyui-boot) | nightly-20261030-b1aa558 | Mulan Public License, Version 2 (Mulan PubL v2) ; gh api : NOASSERTION | [LICENSE](https://raw.githubusercontent.com/YanWenKun/ComfyUI-Docker/b1aa558f82c544b6a5dd0a8cbc56b06897e8e98e/LICENSE) | Voir Obligations détaillées |

- ComfyUI : aucun tag n'est épinglé, l'image déployée est `yanwk/comfyui-boot:nightly-20261030-b1aa558` (`docker-compose.yml`) ; le lien lit LICENSE au dernier commit de master avant le 2026-10-31 (`gh api -X GET repos/Comfy-Org/ComfyUI/commits -f sha=master -f until=2026-10-30T23:59:59Z -f per_page=1` → b5a432157de6b8884f81104cd02926adf4d597e4).
- Docling : le composant déployé est docling-serve (`ghcr.io/docling-project/docling-serve-cu128:v1.38.2`) ; la licence est lue dans docling-project/docling-serve.
- SearXNG : le dépôt n'a pas de tag Git (`git ls-remote --tags https://github.com/searxng/searxng | wc -l` → 0) ; la licence est lue au commit 1cd13d98d65a58f1126fa5bb5c77e42c0ea625f3 de l'image `searxng/searxng:2026.10.30-1cd13d98d`.

## Composants ComfyUI (custom nodes)

| Composant | Version | Licence | Lien | Obligation pour intégrateur |
|-----------|---------|---------|------|----------------------------|
| ComfyUI-Manager | non épinglé (branche main) | GPL-3.0 | [LICENSE.txt](https://raw.githubusercontent.com/Comfy-Org/ComfyUI-Manager/4e4077b0a557d2dbde36b6d5dd30f6dee9f0f641/LICENSE.txt) | Voir obligations GPL (Q4) |
| ComfyUI-GGUF | 6ea2651e | Apache-2.0 | [LICENSE](https://raw.githubusercontent.com/city96/ComfyUI-GGUF/6ea2651e7df66d7585f6ffee804b20e92fb38b8a/LICENSE) | Aucune restriction |
| ComfyUI-KJNodes | 2747d76e | GPL-3.0 | [LICENSE](https://raw.githubusercontent.com/kijai/ComfyUI-KJNodes/2747d76e9855f296e3dabe5ae1d44742c5f7eaff/LICENSE) | Voir obligations GPL (Q4) |
| ComfyUI-VideoHelperSuite | 993082e4 | GPL-3.0 | [LICENSE](https://raw.githubusercontent.com/Kosinkadink/ComfyUI-VideoHelperSuite/993082e4f2473bf4acaf06f51e33877a7eb38960/LICENSE) | Voir obligations GPL (Q4) |
| ComfyUI-LTXVideo | 531512f7 | LTX-2 Community License Agreement ; gh api : NOASSERTION | [LICENSE](https://raw.githubusercontent.com/Lightricks/ComfyUI-LTXVideo/531512f7286963dc7aff1fd8bf5556e95eae03af/LICENSE) | Licence propriétaire, voir conditions |

- Source : `Dockerfile.comfyui`. Aucun fichier du dépôt, hors ce document, ne le référence (`grep -rn 'Dockerfile\.comfyui' . --exclude-dir=.git --exclude=LICENCES.md` → aucune ligne) : `docker-compose.yml` déploie l'image `yanwk/comfyui-boot`.
- ComfyUI-Manager n'y est pas épinglé : le lien lit la branche par défaut main au commit 4e4077b0a557d2dbde36b6d5dd30f6dee9f0f641 (2026-11-01).

## Modèles Hugging Face

Licence = valeurs `license` / `license_name` de l'API Hugging Face (`cardData`), telles quelles (null = champ absent). Base = `base_model` remonté jusqu'au modèle de base.

| Modèle | Licence | Base | Lien |
|--------|---------|------|------|
| DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF | apache-2.0 / null | DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NM-DAU (apache-2.0 / null), puis Qwen/Qwen3.8-27B (apache-2.0 / null) | [repo](https://huggingface.co/DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF) |
| DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF | apache-2.0 / null | DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP (apache-2.0 / null, sans base_model déclaré) ; le README nomme Qwen/Qwen3.5-9B (apache-2.0 / null), dont le base_model est Qwen/Qwen3.5-9B-Base (apache-2.0 / null) | [repo](https://huggingface.co/DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF) |
| Qwen/Qwen-Image-2.1 | other / qwen-research | aucun base_model déclaré | [repo](https://huggingface.co/Qwen/Qwen-Image-2.1) |
| Comfy-Org/Qwen-Image-2.1 | other / qwen-research | Qwen/Qwen-Image-2.1 (other / qwen-research) | [repo](https://huggingface.co/Comfy-Org/Qwen-Image-2.1) |
| abenzerps/Qwen-Image-2.1-Uncensored-Quantized | other / qwen-research | Qwen/Qwen-Image-2.1 (other / qwen-research) | [repo](https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-Quantized) |

## Restrictions d'usage commercial

**⚠️ Licence `other / qwen-research` : le texte contient « FOR NON-COMMERCIAL PURPOSES ONLY » et « without obtaining a separate commercial license ».**

| Dépôt Hugging Face | license | license_name | base_model | Fichiers téléchargés par download-models.sh |
|--------------------|---------|--------------|------------|---------------------------------------------|
| Qwen-Image 2.1 : Qwen/Qwen-Image-2.1 | other | qwen-research | aucun déclaré | 0 |
| Comfy-Org/Qwen-Image-2.1 | other | qwen-research | Qwen/Qwen-Image-2.1 | 4 |
| abenzerps/Qwen-Image-2.1-Uncensored-Quantized | other | qwen-research | Qwen/Qwen-Image-2.1 | 1 |

- Valeurs relevées avec `curl -s https://huggingface.co/api/models/<dépôt> | jq '.cardData | {license, license_name, base_model}'`.
- `download-models.sh` (fonction `download_comfyui_models`, active quand `COMPOSE_PROFILES` contient `comfyui`) télécharge des fichiers depuis Comfy-Org/Qwen-Image-2.1 (`grep -c 'download_file "${HF_COMFY' download-models.sh` → 4) et abenzerps/Qwen-Image-2.1-Uncensored-Quantized (`grep -c 'download_file "${HF_UNC' download-models.sh` → 1), aucun depuis Qwen/Qwen-Image-2.1 (`grep -c 'huggingface.co/Qwen/' download-models.sh` → 0).
- Texte complet : Qwen RESEARCH LICENSE AGREEMENT, Release Date: September 20, 2026 (https://huggingface.co/Qwen/Qwen-Image-2.1/raw/main/LICENSE). L'article 1.i de ce texte définit Non-Commercial (dernière citation ci-dessous).
- Autres composants dont la licence pose des conditions d'usage ou de distribution : n8n (Q1), Open WebUI (Q2), Redis (Q3), GPL et AGPL (Q4), ComfyUI-LTXVideo, LiteLLM, Langfuse et ComfyUI-Docker (Obligations détaillées).

> "You are granted a non-exclusive, worldwide, non-transferable and royalty-free limited license under our intellectual property or other rights owned by us embodied in the Materials to use, reproduce, distribute, copy, create derivative works of, and make modifications to the Materials FOR NON-COMMERCIAL PURPOSES ONLY." — source: https://huggingface.co/Qwen/Qwen-Image-2.1/raw/main/LICENSE
> "You shall not use the Materials for any commercial purpose without obtaining a separate commercial license from us." — source: https://huggingface.co/Qwen/Qwen-Image-2.1/raw/main/LICENSE
> "If you wish to use the Materials commercially, you shall request a license from us at model-business@notice.qwencloud.com." — source: https://huggingface.co/Qwen/Qwen-Image-2.1/raw/main/LICENSE
> ""Non-Commercial" shall mean for research or evaluation purposes only." — source: https://huggingface.co/Qwen/Qwen-Image-2.1/raw/main/LICENSE

## Obligations détaillées

Les clauses de n8n, d'Open WebUI, de Redis, de la GPL, de l'AGPL, d'Obscura et des modèles sont citées dans « Restrictions d'usage commercial » et dans « Questions d'intégrateur ». Ci-dessous : les autres textes.

### LTX-2 Community License

- ComfyUI-LTXVideo au commit 531512f7 : LTX-2 Community License Agreement (date du texte : January 5, 2026) ; `gh api` : NOASSERTION.

> "By using or distributing any portion or element of LTX-2, you agree to be bound by this Agreement." — source: https://raw.githubusercontent.com/Lightricks/ComfyUI-LTXVideo/531512f7286963dc7aff1fd8bf5556e95eae03af/LICENSE

### Portainer CE — Zlib

- `gh api -X GET repos/portainer/portainer/license -f ref=2.45.3 --jq .license.spdx_id` → Zlib.

> "Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:" — source: https://raw.githubusercontent.com/portainer/portainer/2.45.3/LICENSE
> "The origin of this software must not be misrepresented; you must not claim that you wrote the original software." — source: https://raw.githubusercontent.com/portainer/portainer/2.45.3/LICENSE
> "Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software." — source: https://raw.githubusercontent.com/portainer/portainer/2.45.3/LICENSE
> "This notice may not be removed or altered from any source distribution." — source: https://raw.githubusercontent.com/portainer/portainer/2.45.3/LICENSE

### LiteLLM, Langfuse, n8n : parties hors licence principale

- LiteLLM `v1.106.6` : le fichier LICENSE annonce que le contenu du répertoire enterprise/ relève de la licence définie dans enterprise/LICENSE ; au tag, le répertoire existe (`gh api "repos/BerriAI/litellm/contents/enterprise?ref=v1.106.6" --jq '.[].name'` liste LICENSE.md) et la licence s'intitule BerriAI Enterprise license. Contenu de l'image `ghcr.io/berriai/litellm:v1.106.6` : non vérifié.
- Langfuse `v4.72.0` : le contenu des répertoires ee/ relève de `ee/LICENSE` (Langfuse Enterprise license). Contenu des images : non vérifié.
- n8n `n8n@2.45.6` : les fichiers dont le nom contient .ee. ne sont pas sous la Sustainable Use License et relèvent de la n8n Enterprise License (LICENSE_EE.md). Contenu de l'image `docker.n8n.io/n8nio/n8n:2.45.6` : non vérifié.

> "Content outside of the above mentioned directories or restrictions above is available under the MIT license as defined below." — source: https://raw.githubusercontent.com/BerriAI/litellm/v1.106.6/LICENSE
> "Subject to the foregoing, it is forbidden to copy, merge, publish, distribute, sublicense, and/or sell the Software." — source: https://raw.githubusercontent.com/BerriAI/litellm/v1.106.6/enterprise/LICENSE.md
> "Certain parts of the periphery of Langfuse are commercially licensed and governed by this Enterprise License." — source: https://raw.githubusercontent.com/langfuse/langfuse/v4.72.0/ee/LICENSE
> "Source code files that contain ".ee." in their filename or ".ee" in their dirname are NOT licensed under the Sustainable Use License." — source: https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md

### ComfyUI-Docker (image yanwk/comfyui-boot) — Mulan PubL v2

- `yanwk/comfyui-boot:nightly-20261030-b1aa558` (`docker-compose.yml`) : la description Docker Hub (`curl -s https://hub.docker.com/v2/repositories/yanwk/comfyui-boot/ | jq -r .full_description | head -3`) renvoie vers `https://github.com/YanWenKun/ComfyUI-Docker` ; `b1aa558` est un commit de ce dépôt (`gh api repos/YanWenKun/ComfyUI-Docker/commits/b1aa558 --jq .sha` → b1aa558f82c544b6a5dd0a8cbc56b06897e8e98e).
- `gh api -X GET repos/YanWenKun/ComfyUI-Docker/license -f ref=b1aa558f82c544b6a5dd0a8cbc56b06897e8e98e` → NOASSERTION, fichier `LICENSE` (texte chinois et anglais, Mulan Public License, Version 2) : c'est la licence du dépôt qui construit l'image, pas celle de ComfyUI (GPL-3.0, voir Q4).

> "Distribute (or Distribution) means the act of making the Contribution or Derivative Work available to others through any medium, and using the Contribution or Derivative Work to provide online services to users, such as the act of providing online services through a cloud service platform built using Contributions or Derivative Works." — source: https://raw.githubusercontent.com/YanWenKun/ComfyUI-Docker/b1aa558f82c544b6a5dd0a8cbc56b06897e8e98e/LICENSE

## Questions d'intégrateur

### Q1 n8n

- Licence lue au tag `n8n@2.45.6`, fichier `LICENSE.md` : Sustainable Use License, Version 1.0 (`gh api` : NOASSERTION).
- Usage pour ses propres besoins internes : la section Limitations n'autorise l'usage ou la modification que pour les besoins métier internes de l'utilisateur, ou pour un usage non commercial ou personnel (première citation).
- Distribution à des tiers : la même section ne l'autorise que si elle est gratuite et à des fins non commerciales (deuxième citation).
- Le contenu qui n'est pas exclu relève de la Sustainable Use License (troisième citation) ; la section No Other Rights exclut toute licence autre que celles expressément accordées (quatrième citation).
- Ce que le texte ne tranche pas : le cas d'un intégrateur qui exploite n8n pour un client. introuvable : aucune occurrence, insensible à la casse, de integrator, consult, customer, client, resell, host, saas ; commande : `curl -s https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md | grep -c -i -E 'integrator|consult|customer|client|resell|host|saas'` → 0.

> "You may use or modify the software only for your own internal business purposes or for non-commercial or personal use." — source: https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md
> "You may distribute the software or provide it to others only if you do so free of charge for non-commercial purposes." — source: https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md
> "Content outside of the above mentioned files or restrictions is available under the "Sustainable Use License" as defined below." — source: https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md
> "These terms do not imply any licenses other than those expressly granted in these terms." — source: https://raw.githubusercontent.com/n8n-io/n8n/n8n@2.45.6/LICENSE.md

### Q2 Open WebUI

- Licence lue au tag `v0.12.5`, fichier `LICENSE` : Open WebUI License (`gh api` : NOASSERTION) ; clauses 1 à 3 : redistribution du code source et en binaire, non-utilisation des noms du titulaire et des contributeurs pour promouvoir les produits dérivés sans permission écrite préalable ; clause 4 : marque.
- Clause 4 : interdit d'altérer, retirer, masquer ou remplacer la marque « Open WebUI » dans tout déploiement ou distribution, sauf trois exceptions (citation ci-dessous).
- Seuil de l'exception (i) : le nombre total d'utilisateurs finaux (personnes physiques ayant un accès direct à l'application) ne dépasse pas cinquante (50) sur toute période glissante de trente (30) jours ; exception (ii) : permission écrite préalable du titulaire ; exception (iii) : licence entreprise dûment signée.
- Dans ce dépôt : aucun réglage de marque n'est défini ; commande : `grep -rn -i -E 'WEBUI_NAME|favicon|custom\.css' . --exclude-dir=.git --exclude=LICENCES.md | wc -l` → 0.

> "Notwithstanding any other provision of this License, and as a material condition of the rights granted herein, licensees are strictly prohibited from altering, removing, obscuring, or replacing any "Open WebUI" branding, including but not limited to the name, logo, or any visual, textual, or symbolic identifiers that distinguish the software and its interfaces, in any deployment or distribution, except in the following circumstances: (i) deployments or distributions where the total number of end users (defined as individual natural persons with direct access to the application) does not exceed fifty (50) within any rolling thirty (30) day period; (ii) the licensee has obtained specific prior written permission from the copyright holder; or (iii) where the licensee has obtained a duly executed enterprise license expressly permitting such modification." — source: https://raw.githubusercontent.com/open-webui/open-webui/v0.12.5/LICENSE

### Q3 Redis

- Licence lue au tag `7.4.12`, fichier `LICENSE.txt` (`gh api` : NOASSERTION) : double licence Redis Source Available License v2 (RSALv2) ou Server Side Public License v1 (SSPLv1), au choix de l'utilisateur (première citation).
- RSALv2, section Limitations : interdit de mettre à disposition de tiers la fonctionnalité du Software ou d'une version modifiée comme service, ou de la distribuer de façon à la rendre disponible à des tiers ; le paragraphe suivant précise ce que couvre cette mise à disposition (deuxième et troisième citations).
- SSPLv1, article 13 « Offering the Program as a Service » : mettre la fonctionnalité du Program à disposition de tiers comme service impose de rendre le Service Source Code disponible par téléchargement réseau, à tous, sans frais, sous les termes de la licence (quatrième citation).
- Dans ce dépôt : image `redis:7.4.12` (`versions.env`), service `redis` avec `expose: "6379"` et sans clé `ports` (`docker-compose.yml`) ; si cet usage entre dans les textes cités n'est pas tranché ici.
- Alternative libre citée : Valkey (valkey-io/valkey), tag `8.1.11` ; `docker manifest inspect valkey/valkey:8.1.11` → code 0, linux/amd64 présent ; licence lue dans `COPYING` (pas de fichier LICENSE à la racine du tag) : BSD-3-Clause, ligne `SPDX-License-Identifier: BSD-3-Clause` (texte de la licence : cinquième citation) ; le README du tag décrit l'origine du projet (sixième citation) ; compatibilité technique avec les clients de la stack non testée.

> "Starting on March 20th, 2024, Redis follows a dual-licensing model with all Redis project code contributions under version 7.4 and subsequent releases governed by the Redis Software Grant and Contributor License Agreement. After this date, contributions are subject to the user's choice of the Redis Source Available License v2 (RSALv2) or the Server Side Public License v1 (SSPLv1), as follows:" — source: https://raw.githubusercontent.com/redis/redis/7.4.12/LICENSE.txt
> "You may not make the functionality of the Software or a Modified version available to third parties as a service or distribute the Software or a Modified version in a manner that makes the functionality of the Software available to third parties." — source: https://raw.githubusercontent.com/redis/redis/7.4.12/LICENSE.txt
> "Making the functionality of the Software or Modified version available to third parties includes, without limitation, enabling third parties to interact with the functionality of the Software or Modified version in distributed form or remotely through a computer network, offering a product or service, the value of which entirely or primarily derives from the value of the Software or Modified version, or offering a product or service that accomplishes for users the primary purpose of the Software or Modified version." — source: https://raw.githubusercontent.com/redis/redis/7.4.12/LICENSE.txt
> "If you make the functionality of the Program or a modified version available to third parties as a service, you must make the Service Source Code available via network download to everyone at no charge, under the terms of this License." — source: https://raw.githubusercontent.com/redis/redis/7.4.12/LICENSE.txt
> "Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:" — source: https://raw.githubusercontent.com/valkey-io/valkey/8.1.11/COPYING
> "This project was forked from the open source Redis project right before the transition to their new source available licenses." — source: https://raw.githubusercontent.com/valkey-io/valkey/8.1.11/README.md

### Q4 GPL et AGPL

- Licences lues : ComfyUI = GPL-3.0 (`gh api` : GPL-3.0), SearXNG = AGPL-3.0 (`gh api` : AGPL-3.0) ; les deux séries de citations ci-dessous commencent par le titre officiel de chaque texte.
- Installer et exécuter sans modifier : l'article 2 « Basic Permissions » de la GPL-3.0 et de l'AGPL-3.0 contient la même phrase sur l'exécution du programme non modifié ; l'article 0 « Definitions » de la GPL-3.0 exclut du « convey » la simple interaction par réseau sans transfert de copie.
- Livrer une image Docker construite par nous : GPL-3.0 article 4 « Conveying Verbatim Copies », article 5 « Conveying Modified Source Versions » (alinéa c : licence de l'ensemble) et article 6 « Conveying Non-Source Forms » (Corresponding Source) ; l'AGPL-3.0 porte les mêmes numéros et titres pour 4, 5 et 6.
- AGPL-3.0 article 13 « Remote Network Interaction; Use with the GNU General Public License » : l'obligation vise le cas « if you modify the Program » (dernière citation) ; l'article 13 de la GPL-3.0 s'intitule « Use with the GNU Affero General Public License ».
- Dans ce dépôt : `docker-compose.yml` ne contient aucune clé `build:` (`grep -c -E '^\s+build:' docker-compose.yml` → 0), SearXNG et ComfyUI y sont des images tierces, `Dockerfile.comfyui` n'est référencé nulle part (`grep -rn 'Dockerfile\.comfyui' . --exclude-dir=.git --exclude=LICENCES.md` → aucune ligne). introuvable : le mot docker dans les deux textes (`curl -s https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE | grep -c -i docker` → 0 ; `curl -s https://raw.githubusercontent.com/searxng/searxng/1cd13d98d65a58f1126fa5bb5c77e42c0ea625f3/LICENSE | grep -c -i docker` → 0) : ces textes ne tranchent pas le cas d'une image Docker.

> "GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007" — source: https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE
> "This License explicitly affirms your unlimited permission to run the unmodified Program." — source: https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE
> "Mere interaction with a user through a computer network, with no transfer of a copy, is not conveying." — source: https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE
> "You may convey verbatim copies of the Program's source code as you receive it, in any medium, provided that you conspicuously and appropriately publish on each copy an appropriate copyright notice; keep intact all notices stating that this License and any non-permissive terms added in accord with section 7 apply to the code; keep intact all notices of the absence of any warranty; and give all recipients a copy of this License along with the Program." — source: https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE
> "You must license the entire work, as a whole, under this License to anyone who comes into possession of a copy." — source: https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE
> "You may convey a covered work in object code form under the terms of sections 4 and 5, provided that you also convey the machine-readable Corresponding Source under the terms of this License, in one of these ways:" — source: https://raw.githubusercontent.com/comfyanonymous/ComfyUI/b5a432157de6b8884f81104cd02926adf4d597e4/LICENSE
> "GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007" — source: https://raw.githubusercontent.com/searxng/searxng/1cd13d98d65a58f1126fa5bb5c77e42c0ea625f3/LICENSE
> "This License explicitly affirms your unlimited permission to run the unmodified Program." — source: https://raw.githubusercontent.com/searxng/searxng/1cd13d98d65a58f1126fa5bb5c77e42c0ea625f3/LICENSE
> "Notwithstanding any other provision of this License, if you modify the Program, your modified version must prominently offer all users interacting with it remotely through a computer network (if your version supports such interaction) an opportunity to receive the Corresponding Source of your version by providing access to the Corresponding Source from a network server at no charge, through some standard or customary means of facilitating copying of software." — source: https://raw.githubusercontent.com/searxng/searxng/1cd13d98d65a58f1126fa5bb5c77e42c0ea625f3/LICENSE

### Q5 Obscura

- Dépôt source : https://github.com/h4ckf0r0day/obscura (`gh api repos/h4ckf0r0day/obscura` : description « The headless browser for AI agents and web scraping », branche par défaut main, non archivé, non fork) ; la description Docker Hub de `h4ckf0r0day/obscura` renvoie vers ce dépôt.
- Version déployée : image `h4ckf0r0day/obscura:0.2.5` (`versions.env`) ; tag Git `v0.2.5` ; `docker manifest inspect h4ckf0r0day/obscura:0.2.5` → code 0, linux/amd64 et linux/arm64.
- Licence : Apache-2.0 (`gh api -X GET repos/h4ckf0r0day/obscura/license -f ref=v0.2.5` → Apache-2.0, fichier `LICENSE`) ; le Cargo.toml du tag déclare `license = "Apache-2.0"` et le README, section License, indique « Apache 2.0 ».
- Le fichier LICENSE est le texte Apache License, Version 2.0, January 2004, avec le champ `Copyright [yyyy] [name of copyright owner]` de l'annexe non rempli ; `gh api "repos/h4ckf0r0day/obscura/contents/?ref=v0.2.5" --jq '.[].name' | grep -c -i notice` → 0 (aucun fichier NOTICE à la racine).

> "Licensed under the Apache License, Version 2.0" — source: https://raw.githubusercontent.com/h4ckf0r0day/obscura/v0.2.5/LICENSE
> "Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form." — source: https://raw.githubusercontent.com/h4ckf0r0day/obscura/v0.2.5/LICENSE

### Q6 Modèles DavidAU et abenzerps

- DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF : license apache-2.0, license_name null ; base_model DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NM-DAU (apache-2.0), dont le base_model est Qwen/Qwen3.8-27B (apache-2.0, sans base_model) ; le LICENSE de Qwen/Qwen3.8-27B est le texte Apache License Version 2.0 (première citation).
- DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF : license apache-2.0, license_name null ; base_model DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP (apache-2.0, sans base_model déclaré) ; son README nomme Qwen/Qwen3.5-9B comme Original model : apache-2.0, base_model Qwen/Qwen3.5-9B-Base (apache-2.0, sans base_model) ; le LICENSE de Qwen/Qwen3.5-9B est le texte Apache License Version 2.0 (seconde citation).
- abenzerps/Qwen-Image-2.1-Uncensored-Quantized : license other, license_name qwen-research ; base_model Qwen/Qwen-Image-2.1 (other / qwen-research, sans base_model) ; voir Restrictions d'usage commercial (troisième citation).
- introuvable : fichier LICENSE dans les trois dépôts DavidAU 27B, DavidAU 9B et abenzerps ; commande : `curl -s -o /dev/null -w '%{http_code}' https://huggingface.co/<dépôt>/raw/main/LICENSE` → 404 pour chacun ; les licences déclarées viennent de `cardData` (API).

> "Licensed under the Apache License, Version 2.0" — source: https://huggingface.co/Qwen/Qwen3.8-27B/raw/main/LICENSE
> "Licensed under the Apache License, Version 2.0" — source: https://huggingface.co/Qwen/Qwen3.5-9B/raw/main/LICENSE
> "You are granted a non-exclusive, worldwide, non-transferable and royalty-free limited license under our intellectual property or other rights owned by us embodied in the Materials to use, reproduce, distribute, copy, create derivative works of, and make modifications to the Materials FOR NON-COMMERCIAL PURPOSES ONLY." — source: https://huggingface.co/Qwen/Qwen-Image-2.1/raw/main/LICENSE

À faire valider par un juriste.
