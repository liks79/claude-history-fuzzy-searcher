# cc-hist — Claude Code History Fuzzy Searcher

Fuzzy search your [Claude Code](https://claude.ai/code) chat history using [fzf](https://github.com/junegunn/fzf).  
Opens as a **popup window** (tmux/Zellij) or an inline panel, and integrates directly with Claude Code via a keyboard shortcut.

## Features

- **Fuzzy search** across all Claude Code chat history entries
- **Popup effect** — opens as a floating overlay in tmux (or inline in other terminals)
- **Claude Code keybinding** — press `Ctrl+T` inside Claude Code to instantly search and insert a past message
- Deduplicates and sorts entries **newest-first**
- Shows project name and timestamp for each entry
- **Preview pane** (`Ctrl+/`) shows the full message text
- Pure shell + Python — no additional runtime dependencies beyond fzf and python3

## Requirements

| Tool     | Version  | Install |
|----------|----------|---------|
| [fzf](https://github.com/junegunn/fzf) | ≥ 0.53   | `brew install fzf` / `apt install fzf` |
| python3  | ≥ 3.8    | bundled on most systems |
| tmux     | ≥ 3.3 *(optional)* | for popup window effect |
| [Claude Code](https://claude.ai/code) | any | must have run at least once |

## Installation

```bash
git clone https://github.com/liks79/claude-history-fuzzy-searcher.git
cd claude-history-fuzzy-searcher
bash install.sh
```

The installer:
1. Copies `cc-hist` and `cc-hist-edit` to `~/.local/bin/`
2. Adds `Ctrl+T → chat:externalEditor` to `~/.claude/keybindings.json`
3. Sets `EDITOR=cc-hist-edit` in `~/.claude/settings.json` (saves your original editor as `CC_FALLBACK_EDITOR`)

> **Custom install directory**  
> `INSTALL_DIR=/usr/local/bin bash install.sh`

## Usage

### Inside Claude Code (recommended)

Press **`Ctrl+T`** while the chat input is focused.

- fzf opens as a **popup** (tmux) or inline panel
- Type to fuzzy-search your history
- `Enter` — insert the selected message into the chat draft
- `Ctrl+/` — toggle the full-message preview pane
- `Esc` — cancel

### Standalone (terminal)

```bash
# Interactive search, print selected message to stdout
cc-hist

# Write selected message to a file
cc-hist -o /tmp/draft.txt

# Pre-fill the search query
cc-hist -q "deploy"

# Pipe the result to the clipboard
cc-hist | pbcopy          # macOS
cc-hist | xclip -sel clip # Linux (X11)
cc-hist | wl-copy         # Linux (Wayland)
```

## How the popup works

| Environment | Behavior |
|-------------|----------|
| **tmux** (≥ 3.3) | Floating popup window via `fzf --tmux center,80%,60%` |
| **Zellij** (≥ 0.44) | Floating popup via `fzf --popup` |
| **Other terminals** | Inline panel at bottom, 60% screen height |

## How the Claude Code integration works

Claude Code's `chat:externalEditor` keybinding pauses the TUI, calls `$EDITOR` with a temp file, and inserts whatever you write to that file back into the chat draft.

`cc-hist-edit` acts as that `$EDITOR` — it runs `cc-hist`, captures the selection, and writes it to the temp file that Claude Code then reads.

```
Ctrl+T
  └─ chat:externalEditor
       └─ $EDITOR = cc-hist-edit
            └─ cc-hist (fzf popup)
                 └─ selected message → temp file → chat draft
```

> **Note on `ctrl+g`**  
> If you had `ctrl+g` mapped to `chat:externalEditor` before installing, that binding will now also open history search (since both call `$EDITOR`). To get a separate "open in nvim" binding back, restore your original editor in `~/.claude/settings.json` under `CC_FALLBACK_EDITOR`, or create a second wrapper script.

## Configuration

### Claude Code keybindings

Edit `~/.claude/keybindings.json` to change or add shortcuts:

```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+t": "chat:externalEditor"
      }
    }
  ]
}
```

### Custom Claude Code data directory

```bash
CLAUDE_HOME=/path/to/.claude cc-hist
```

## Advanced usage

### Tmux key binding

You can bind `cc-hist` to a tmux key so it opens as a popup from any terminal window — not just inside Claude Code.

Add to `~/.tmux.conf`:

```tmux
# Paste selected history into the active pane
bind-key -n C-h run-shell "cc-hist -o /tmp/cc-hist-tmux.txt && tmux load-buffer /tmp/cc-hist-tmux.txt && tmux paste-buffer"
```

Or copy to clipboard instead of pasting:

```tmux
# macOS
bind-key -n C-h display-popup -E -w 80% -h 60% "cc-hist | pbcopy"
# Linux (X11)
bind-key -n C-h display-popup -E -w 80% -h 60% "cc-hist | xclip -sel clip"
```

Reload your config with `tmux source ~/.tmux.conf`.

### Using cc-hist alongside your existing `$EDITOR`

By default `install.sh` sets `EDITOR=cc-hist-edit` in Claude Code's `settings.json`, routing every `chat:externalEditor` invocation to history search. If you want to keep a real editor (e.g. `nvim`) for editing non-empty drafts and only open history search for empty ones, use a **smart wrapper**:

**Step 1 — create `~/.local/bin/smart-editor`**

```bash
#!/usr/bin/env bash
# Empty file → history search; non-empty file → open in $EDITOR_FALLBACK
TMPFILE="${1:-}"
if [[ -n "$TMPFILE" && ! -s "$TMPFILE" ]]; then
    exec cc-hist --output "$TMPFILE"
else
    exec "${EDITOR_FALLBACK:-nvim}" "$TMPFILE"
fi
```

```bash
chmod +x ~/.local/bin/smart-editor
```

**Step 2 — update `~/.claude/settings.json`**

```json
{
  "env": {
    "EDITOR": "smart-editor",
    "EDITOR_FALLBACK": "nvim"
  }
}
```

Now `Ctrl+T` on an empty draft opens history search; invoking `chat:externalEditor` on an existing draft opens nvim.

## Uninstall

```bash
bash uninstall.sh
```

Removes the binaries and restores your original Claude Code `EDITOR` and keybindings.

## Data source

cc-hist reads `~/.claude/history.jsonl` — the same file Claude Code uses to populate its built-in history navigation. No conversation content, tool outputs, or assistant responses are read or transmitted anywhere; only user-typed messages are indexed.

## License

[BSD 2-Clause](LICENSE) © 2025–2026 liks79
