# Inventaire des licences — Stack universelle

Vérifié le 2026-11-01 (docker manifest inspect, linux/amd64).

## Composants de la stack

| Composant | Version | Licence | Lien | Obligation pour intégrateur |
|-----------|---------|---------|------|----------------------------|
| PostgreSQL | 17.11 | PostgreSQL License | [LICENSE](https://www.postgresql.org/about/licence/) | Aucune restriction d'usage commercial |
| Redis | 7.4.12 | BSD-3-Clause | [LICENSE](https://redis.io/docs/latest/operate/oss_and_stack/install/install-redis/install-redis-from-source/) | Aucune restriction d'usage commercial |
| Qdrant | v1.20.0 | Apache-2.0 | [LICENSE](https://github.com/qdrant/qdrant/blob/master/LICENSE) | Aucune restriction d'usage commercial |
| Ollama | 0.40.13 | MIT | [LICENSE](https://github.com/ollama/ollama/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| llama.cpp | server-cuda-b11206 | MIT | [LICENSE](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE) | Aucune restriction d'usage commercial |
| LiteLLM | v1.106.6 | MIT | [LICENSE](https://github.com/BerriAI/litellm/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| Open WebUI | v0.12.5 | BSD-3-Clause (clause marque) | [LICENSE](https://github.com/open-webui/open-webui/blob/main/LICENSE) | Voir clause marque (50 utilisateurs) |
| n8n | 2.45.6 | Sustainable Use License | [LICENSE.md](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) | Distribution gratuite et non commerciale uniquement |
| Docling | v1.38.2 | MIT | [LICENSE](https://github.com/docling-project/docling/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| Kokoro-FastAPI | v0.9.1 | Apache-2.0 | [LICENSE](https://github.com/remsky/kokoro-fastapi/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| Speaches | 0.8.3 | MIT | [LICENSE](https://github.com/speaches-ai/speaches/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| ClickHouse | 25.12.11.4 | Apache-2.0 | [LICENSE](https://github.com/ClickHouse/ClickHouse/blob/master/LICENSE) | Aucune restriction d'usage commercial |
| RustFS | 1.0.4 | Apache-2.0 | [LICENSE](https://github.com/rustfs/rustfs/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| aws-cli | 2.39.2 | Apache-2.0 | [LICENSE](https://github.com/aws/aws-cli/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| Langfuse | 4.72.0 | MIT | [LICENSE](https://github.com/langfuse/langfuse/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| SearXNG | 2026.10.30 | AGPL-3.0 | [LICENSE](https://github.com/searxng/searxng/blob/master/COPYING) | Voir obligations AGPL (ci-dessous) |
| Portainer CE | 2.45.3 | Apache-2.0 | [LICENSE](https://github.com/portainer/portainer/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| Caddy | 2.11.7 | Apache-2.0 | [LICENSE](https://github.com/caddyserver/caddy/blob/master/LICENSE) | Aucune restriction d'usage commercial |
| Obscura | 0.2.5 | Apache-2.0 | [LICENSE](https://github.com/h4ckf0r0day/obscura/blob/main/LICENSE) | Aucune restriction d'usage commercial |
| ComfyUI | nightly-20261030 | GPL-3.0 | [LICENSE](https://github.com/comfyanonymous/ComfyUI/blob/master/LICENSE) | Voir obligations GPL (ci-dessous) |

## Composants ComfyUI (custom nodes)

| Composant | Version | Licence | Lien | Obligation pour intégrateur |
|-----------|---------|---------|------|----------------------------|
| ComfyUI-Manager | master | GPL-3.0 | [LICENSE](https://github.com/Comfy-Org/ComfyUI-Manager/blob/master/LICENSE) | Voir obligations GPL |
| ComfyUI-GGUF | 6ea2651e | Apache-2.0 | [LICENSE](https://github.com/city96/ComfyUI-GGUF/blob/main/LICENSE) | Aucune restriction |
| ComfyUI-KJNodes | 2747d76e | GPL-3.0 | [LICENSE](https://github.com/kijai/ComfyUI-KJNodes/blob/master/LICENSE) | Voir obligations GPL |
| ComfyUI-VideoHelperSuite | 993082e4 | GPL-3.0 | [LICENSE](https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite/blob/master/LICENSE) | Voir obligations GPL |
| ComfyUI-LTXVideo | 531512f7 | LTX-2 Community License | [LICENSE](https://github.com/Lightricks/ComfyUI-LTXVideo/blob/master/LICENSE) | Licence propriétaire, voir conditions |

## Modèles Hugging Face

| Modèle | Licence | Base | Lien |
|--------|---------|------|------|
| DavidAU/Qwen3.8-27B-TURBO-Fable...-GGUF | Apache-2.0 | Qwen/Qwen3.8-27B (Apache-2.0) | [repo](https://huggingface.co/DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF) |
| DavidAU/Qwen3.5-9B-The-Defiant-Fable...-GGUF | Apache-2.0 | Qwen3.5-9B (Apache-2.0) | [repo](https://huggingface.co/DavidAU/Qwen3.5-9B-The-Defiant-Fable-Uncensored-Heretic-NEO-IMATRIX-MAX-MTP-GGUF) |
| Comfy-Org/Qwen-Image-2.1 | Qwen RESEARCH LICENSE | Qwen/Qwen-Image-2.1 | [repo](https://huggingface.co/Comfy-Org/Qwen-Image-2.1) |
| abenzerps/Qwen-Image-2.1-Uncensored-Quantized | Qwen RESEARCH LICENSE | Qwen/Qwen-Image-2.1 | [repo](https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-Quantized) |

## Obligations détaillées

### n8n — Sustainable Use License

"Portions of this software are licensed as follows:
- Content of branches other than the main branch (i.e. "master") are not licensed.
- Source code files that contain ".ee." in their filename or ".ee" in their dirname are NOT licensed under the Sustainable Use License.
- All third party components incorporated into the n8n Software are licensed under the original license provided by the owner of the applicable component.
- Content outside of the above mentioned files or restrictions is available under the "Sustainable Use License" as defined below."

"You may use or modify the software only for your own internal business purposes or for non-commercial or personal use. You may distribute the software or provide it to others only if you do so free of charge for non-commercial purposes."

### Open WebUI — Clause marque

"Notwithstanding any other provision of this License, and as a material condition of the rights granted herein, licensees are strictly prohibited from altering, removing, obscuring, or replacing any "Open WebUI" branding, including but not limited to the name, logo, or any visual, textual, or symbolic identifiers that distinguish the software and its interfaces, in any deployment or distribution, except in the following circumstances: (i) deployments or distributions where the total number of end users (defined as individual natural persons with direct access to the application) does not exceed fifty (50) within any rolling thirty (30) day period; (ii) the licensee has obtained specific prior written permission from the copyright holder; or (iii) where the licensee has obtained a duly executed enterprise license expressly permitting such modification."

### SearXNG — AGPL-3.0

"If you modify the work, you must... make the modified work available as source code... under the terms of the AGPL."

### ComfyUI — GPL-3.0

"If you modify the work, you must... make the modified work available as source code... under the terms of the GPL."

### Qwen RESEARCH LICENSE

"You are granted a non-exclusive, worldwide, non-transferable and royalty-free limited license under our intellectual property or other rights owned by us embodied in the Materials to use, reproduce, distribute, copy, create derivative works of, and make modifications to the Materials FOR NON-COMMERCIAL PURPOSES ONLY."

"You shall not use the Materials for any commercial purpose without obtaining a separate commercial license from us. If you wish to use the Materials commercially, you shall request a license from us at model-business@notice.qwencloud.com."

### LTX-2 Community License

"By using or distributing any portion or element of LTX-2, you agree to be bound by this Agreement."

À faire valider par un juriste.
