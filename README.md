# Air-Gapped `cheat.sh`

This repo wraps upstream `chubin/cheat.sh` into a local-only deployment that can run in an air-gapped environment after an initial online bootstrap.

It builds a local stack with:

- upstream `cheat.sh` cloned into `app/`
- mirrored content repositories in `app/upstream/`
- Redis for the cache layer
- Docker Compose on a fixed IP `11.76.88.254`

The local service serves mirrored cheat sheet repositories offline. Free-form programming-language questions such as `/python/read+json` are intentionally disabled and return a local offline-only message instead of attempting upstream network access.

## Prerequisites

- `git`
- `docker`
- Docker Compose (`docker compose`)

## Initial Setup

This step requires temporary internet access.

```bash
./scripts/init_sources.sh
docker compose up -d --build
```

`./scripts/init_sources.sh` clones:

- `chubin/cheat.sh`
- `tldr-pages/tldr`
- `cheat/cheatsheets`
- `adambard/learnxinyminutes-docs`
- `chubin/cheat.sheets`

It also patches the upstream app into offline-only mode by:

- replacing `app/etc/config.yaml` with a local-only adapter configuration
- replacing `app/lib/adapter/question.py` with a deterministic offline message
- replacing `app/Dockerfile` with an air-gapped build that does not fetch content during image build

## Run

Start the service:

```bash
docker compose up -d --build
```

The `cheatsh` container runs on fixed IP `11.76.88.254` inside `cheatsh_network` and listens on port `80`.

Example queries:

```bash
curl 11.76.88.254/:help
curl 11.76.88.254/ls
CHTSH_URL=11.76.88.254 cht.sh tar # client script
CHTSH_URL=11.76.88.254 cht.sh --shell # client script interactive
echo "stealth" | CHTSH_URL=11.76.88.254 cht.sh --shell # automated local lookup does not work that well
```

automated reading of clipboard is intrusive, better stick to direct invocation

## Offline Behavior

These work offline once the mirrors have been cloned:

- command pages such as `/tar`
- repository-backed language pages such as `/python/:list`
- learn pages such as `/go/:learn`
- global topic listing through `/:list`

These do not work offline and return a local-only message:

- free-form question routes such as `/python/read+json`

## Updating Mirrors

This step requires temporary internet access.

```bash
./scripts/update.sh
```

The update script:

- pulls the upstream `cheat.sh` checkout in `app/`
- fetches and fast-forwards every mirrored repository in `app/upstream/`
- reapplies the offline-only patches
- rebuilds and restarts the Compose stack

## Files

- `scripts/init_sources.sh`: clone and patch the upstream app plus mirrored content
- `scripts/update.sh`: refresh mirrors and restart the stack
- `scripts/apply_airgap_patch.sh`: reapply local-only config and code patches after upstream updates
- `templates/config.yaml`: offline-only `cheat.sh` config override
- `templates/question.py`: deterministic response for unsupported free-form queries
- `templates/Dockerfile.airgapped`: image build without network fetch during container build

## stealth mode

```
echo "stealth" | (CHTSH_URL=http://11.76.88.254 cht.sh --shell)
```
