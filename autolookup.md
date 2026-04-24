# Autolookup

This repo ships a host-side KDE/Plasma clipboard watcher at `scripts/autolookup.sh`.
It is intentionally outside the container stack: the local `cheat.sh` service
stays unchanged, and autolookup is just a terminal helper around it.

## Behavior

- uses Klipper D-Bus signals to react to clipboard changes without polling
- reads the current clipboard contents from Klipper
- extracts the first whitespace-delimited token from copied text
- records each new first word once in a state file
- renders the current lookup into a cache file and opens it in `less -R` at the top
- interrupts the current `less` session and reopens it when a new first word arrives
- ignores clipboard updates whose first token is unchanged

Examples:

- copying `git` looks up `git`
- copying `git status` still looks up `git`
- copying the same token again does not reopen the pager or append a duplicate entry

## Run

```bash
./scripts/autolookup.sh
```

The script expects:

- KDE Plasma with Klipper
- `qdbus6`
- `dbus-monitor`
- `less`
- a working `cht.sh` client
- the local q service reachable at `11.76.88.254` unless overridden

## Environment Overrides

```bash
AUTOLOOKUP_CHTSH_COMMAND=cht.sh
AUTOLOOKUP_STATE_DIR="<repo>/.autolookup/state"
AUTOLOOKUP_CACHE_DIR="<repo>/.autolookup/cache"
AUTOLOOKUP_WORDS_FILE="<repo>/.autolookup/state/autolookup.words"
AUTOLOOKUP_RENDER_FILE="<repo>/.autolookup/cache/autolookup.current"
```

## Design Notes

This avoids repeated clipboard polling and avoids compositor-specific Wayland
watch support. On KDE Neon, Klipper already exposes clipboard change events
over D-Bus, which is the cleanest trigger for a copy-driven workflow. The
script keeps a small registry of seen first words for traceability, but the
terminal view always reflects only the latest lookup so the result matches the
shape of `cht.sh "$word" | less -R`.
