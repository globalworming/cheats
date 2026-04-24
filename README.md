# Air-Gapped `cheat.sh`

This repo wraps upstream `chubin/cheat.sh` into a local-only deployment that can run in an air-gapped environment after an initial online bootstrap.

It builds a local stack with:

- upstream `cheat.sh` cloned into `app/`
- mirrored content repositories in `app/upstream/`
- tracked personal sheets in `sources/personal/`, mounted into the app as a local source
- Redis for the cache layer
- Docker Compose on a fixed IP `11.76.88.254`

The local service serves mirrored cheat sheet repositories offline. Free-form programming-language questions such as `/python/read+json` are intentionally disabled and return a local offline-only message instead of attempting upstream network access.
Normal lookups prefer your personal sheets first when a matching topic exists.

## Prerequisites

- `git`
- `docker`
- Docker Compose (`docker compose`)
- KDE Plasma with Klipper, `qdbus6`, and `dbus-monitor` for `scripts/autolookup.sh`

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
- adding `app/lib/adapter/personal.py` and configuring routing so personal sheets are checked before mirrored upstream sources
- replacing `app/Dockerfile` with an air-gapped build that does not fetch content during image build

## Run

Start the service:

```bash
docker compose up -d
```

The `cheatsh` container runs on fixed IP `11.76.88.254` inside `cheatsh_network` and listens on port `80`.

Example queries:

```bash
curl 11.76.88.254/:help
curl 11.76.88.254/ls
curl 11.76.88.254/git
curl 11.76.88.254/personal:git
# with client
CHTSH_URL=11.76.88.254 cht.sh tar # client script
CHTSH_URL=11.76.88.254 cht.sh --shell # client script interactive
cht.sh tar # if your local client is already pinned to the local server
```

## Autolookup

For a terminal-driven lookup workflow on KDE Plasma, use `scripts/autolookup.sh`.
It listens for Klipper clipboard updates, extracts the first token from copied
text, stores each new first word once, and redraws the terminal with the
corresponding local cheat lookup whenever that first token changes.

Start it in a terminal:

```bash
./scripts/autolookup.sh
```

## Offline Behavior

These work offline once the mirrors have been cloned:

- command pages such as `/tar`
- personal overrides such as `/git` when `sources/personal/git` exists
- explicit personal lookups such as `personal:git`
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

Your personal sheets in `sources/personal/` are not touched by `update.sh`.

## Personal Sheets

Personal sheets live in `sources/personal/` and are tracked in this repository.
Each file name is the topic key used by cheat.sh, using a flat layout:

```text
sources/personal/git
sources/personal/docker
sources/personal/kubectl
```

Behavior:

- `/git` returns `sources/personal/git` before any upstream sheet with the same topic
- `personal:git` always returns the personal sheet directly
- topics with no personal sheet fall back to the existing upstream sources

After adding or editing a personal sheet, rebuild or restart the stack so the running service reloads it:

```bash
docker compose up -d --build
```

## Files

- `scripts/init_sources.sh`: clone and patch the upstream app plus mirrored content
- `scripts/update.sh`: refresh mirrors and restart the stack
- `scripts/apply_airgap_patch.sh`: reapply local-only config and code patches after upstream updates
- `scripts/autolookup.sh`: KDE Klipper clipboard watcher that reopens `less` for each new first word
- `sources/personal/`: tracked personal knowledge base, mounted into the running service
- `templates/config.yaml`: offline-only `cheat.sh` config override
- `templates/personal.py`: local flat-file adapter for the personal source
- `templates/question.py`: deterministic response for unsupported free-form queries
- `templates/Dockerfile.airgapped`: image build without network fetch during container build
