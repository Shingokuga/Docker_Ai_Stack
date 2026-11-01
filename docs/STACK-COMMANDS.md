# Stack Commands Reference

This document covers all `./stack` subcommands for managing the Docker_Ai_Stack.

## Quick Start

```bash
# Start the stack
./stack start

# View running services
./stack ps

# View logs
./stack logs

# Stop the stack
./stack stop
```

## Subcommands

### `./stack versions`

Display all component versions from `versions.env` and running containers.

```bash
$ ./stack versions

=== Docker_Ai_Stack Versions ===

From versions.env:
--------------------
  IMG_POSTGRES:       postgres:17.11
  IMG_REDIS:          redis:7.4.12
  IMG_QDRANT:         qdrant/qdrant:v1.20.0
  IMG_OLLAMA:         ollama/ollama:0.40.13
  ...

Running containers:
-------------------
NAME                    IMAGE                    STATUS
docker_stack_postgres   postgres:17.11           Up 2 hours
...
```

### `./stack update [service...]`

Update versions with automatic rollback if tests fail.

**Without arguments** — update all services:
```bash
./stack update
```

**With specific services:**
```bash
./stack update ollama litellm
```

**Update flow:**
1. Creates backup of `versions.env` in `.wts/updates/`
2. Checks for newer image versions
3. Recreates affected containers
4. Runs `test-stack.sh` to verify health
5. On failure: automatically rolls back to backup
6. On success: cleans up backup

### `./stack pull [service...]`

Pull latest images without recreating containers.

```bash
./stack pull ollama
./stack pull  # all services
```

### `./stack ps`

Show running containers with status.

```bash
$ ./stack ps
NAME                    IMAGE                    STATUS
docker_stack_postgres   postgres:17.11           Up 2 hours
docker_stack_redis      redis:7.4.12             Up 2 hours
...
```

### `./stack logs [service]`

View logs in follow mode.

```bash
# All services
./stack logs

# Specific service
./stack logs ollama
./stack logs open-webui
```

### `./stack start`

Start the entire stack.

```bash
./stack start
```

### `./stack stop`

Stop all containers (data preserved).

```bash
./stack stop
```

### `./stack restart [service]`

Restart the stack or a specific service.

```bash
# Restart all
./stack restart

# Restart specific service
./stack restart litellm
```

### `./stack down`

Tear down the stack (remove containers, networks).

```bash
./stack down
```

### `./stack exec <service> <cmd>`

Execute a command in a running container.

```bash
# Run shell in ollama
./stack exec ollama bash

# Check version
./stack exec litellm litellm --version
```

### `./stack compose [args...]`

Pass-through to docker compose for advanced operations.

```bash
./stack compose config
./stack compose scale n8n-worker=3
./stack compose up -d --no-deps redis
```

## Service Names

Use these service names with commands like `update`, `logs`, `exec`, `restart`:

| Service | Variable | Description |
|---------|----------|-------------|
| postgres | IMG_POSTGRES | PostgreSQL database |
| redis | IMG_REDIS | Redis cache |
| qdrant | IMG_QDRANT | Vector database |
| ollama | IMG_OLLAMA | Ollama LLM runtime |
| llama-server | IMG_LLAMA | llama.cpp server |
| litellm | IMG_LITELLM | LiteLLM proxy |
| open-webui | IMG_OPENWEBUI | Open WebUI frontend |
| n8n | IMG_N8N | n8n workflow automation |
| docling-serve | IMG_DOCLING | Docling document processing |
| searxng | IMG_SEARXNG | SearXNG search engine |
| portainer | IMG_PORTAINER | Portainer management UI |
| caddy | IMG_CADDY | Caddy reverse proxy |
| obscura | IMG_OBSCURA | Obscura service |
| kokoro | IMG_KOKORO | Kokoro TTS |
| whisper | IMG_WHISPER | Speaches (faster-whisper) |
| clickhouse | IMG_CLICKHOUSE | ClickHouse OLAP database |
| s3 | IMG_S3 | RustFS S3-compatible storage |
| langfuse-web | IMG_LANGFUSE_WEB | Langfuse web app |
| langfuse-worker | IMG_LANGFUSE_WORKER | Langfuse worker |

## Update with Rollback Example

```bash
$ ./stack update ollama

=== Docker_Ai_Stack Update ===

Updating services: ollama

Step 1/5: Creating backup...
  Backup saved to: .wts/updates/20261101_143000/versions.env.bak

Step 2/5: Checking for newer versions...
  ollama: checking ollama/ollama:0.40.13
  ollama: updated

Step 3/5: Recreating affected containers...
  Recreating: ollama
  docker_stack_ollama_1  Restarting (0) ...

Step 4/5: Testing stack health...
  ✓ ollama: healthy
  ...

Step 5/5: Test PASSED

=== Update Complete ===
```

## Troubleshooting

**Update failed and rolled back:**
```bash
# Check what went wrong
./stack logs ollama

# Check backup location
ls .wts/updates/
```

**Service not starting after update:**
```bash
# View compose config
./stack compose config

# Check container status
./stack ps

# Restart specific service
./stack restart service-name
```
