# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`cc-hist` is a pure shell + Python fuzzy searcher for Claude Code chat history. It has no build step, no package manager, and no test suite — the entire implementation lives in two executable shell scripts in `bin/`.

## Running and testing

```bash
# Run directly from the repo (no install needed)
bash bin/cc-hist
bash bin/cc-hist -o /tmp/out.txt -q "deploy"

# Install into ~/.local/bin and configure Claude Code
bash install.sh

# Undo everything install.sh did
bash uninstall.sh

# Use a custom install prefix
INSTALL_DIR=/usr/local/bin bash install.sh

# Point at a non-default Claude data directory
CLAUDE_HOME=/path/to/.claude bash bin/cc-hist
```

There is no automated test suite. Test by running the binary manually and verifying fzf output.

## Architecture

```
Ctrl+T (Claude Code)
  └─ chat:externalEditor  (keybinding in ~/.claude/keybindings.json)
       └─ $EDITOR = cc-hist-edit  (set in ~/.claude/settings.json env)
            └─ bin/cc-hist-edit   (thin wrapper: passes its $1 as -o to cc-hist)
                 └─ bin/cc-hist   (fzf popup, writes selection to the temp file)
```

**`bin/cc-hist`** — the main script:
1. Reads `~/.claude/history.jsonl` (fields: `display`, `timestamp`, `project`)
2. Runs an embedded Python snippet to parse, deduplicate (newest-wins), and sort entries newest-first; writes `entries.json` and `display.txt` to a mktemp workdir
3. Runs `fzf` with a tab-delimited display file; a second embedded Python snippet serves as the `--preview` command
4. Extracts the selected entry's full `msg` from `entries.json` and writes it to stdout or `-o FILE`

**`bin/cc-hist-edit`** — the `$EDITOR` shim: receives the temp file path from Claude Code and delegates to `cc-hist --output "$TMPFILE"`.

**`install.sh`** / **`uninstall.sh`** — use embedded Python to surgically read/write `~/.claude/keybindings.json` and `~/.claude/settings.json` without clobbering unrelated keys. `install.sh` saves any pre-existing `EDITOR` value as `CC_FALLBACK_EDITOR` so `uninstall.sh` can restore it.

## Key constraints

- Popup mode is detected at runtime: `$TMUX` → `fzf --tmux`, `$ZELLIJ_SESSION_NAME` → `fzf --popup`, otherwise inline with `--height`.
- History entries are skipped when `display` is empty, starts with `"init"` (prefix match, not exact), or equals `"/"`.
- The `display` field from JSONL is stored as `msg` in the parsed entries dict; both names appear in the code.
- The index column (column 1 in the tab-delimited fzf input) is hidden via `--with-nth=2` but used by the preview script and the final extraction step.
- The preview pane is hidden by default; `Ctrl+/` toggles it.
- `fzf` ≥ 0.53 and `python3` ≥ 3.8 are the only runtime dependencies.
- Only `~/.claude/history.jsonl` is read — only user-typed messages, no conversation content or assistant responses.
