# cc-hist — Claude Code History Fuzzy Searcher

Fuzzy search your [Claude Code](https://claude.ai/code) chat history using [fzf](https://github.com/junegunn/fzf).  
Opens as a **popup window** (tmux/Zellij) or an inline panel, and integrates directly with Claude Code via a keyboard shortcut.

![demo placeholder](https://via.placeholder.com/800x400?text=cc-hist+demo)

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
# Ctrl+H opens Claude Code history search as a tmux popup
bind-key -n C-h display-popup -E -w 80% -h 60% "cc-hist -o /tmp/cc-hist-tmux.txt && cat /tmp/cc-hist-tmux.txt | pbcopy"
```

Or, if you want the selection pasted directly into the active pane:

```tmux
bind-key -n C-h run-shell "cc-hist -o /tmp/cc-hist-tmux.txt && tmux load-buffer /tmp/cc-hist-tmux.txt && tmux paste-buffer"
```

Reload your config with `tmux source ~/.tmux.conf`.

### Standalone terminal usage

`cc-hist` works as a plain CLI tool — no Claude Code required.

```bash
# Interactive search, print selected message to stdout
cc-hist

# Write selected message to a file
cc-hist -o /tmp/draft.txt

# Pre-fill the search query
cc-hist -q "deploy"

# Pipe the result into another command
cc-hist | pbcopy          # macOS — copy to clipboard
cc-hist | xclip -sel clip # Linux — copy to clipboard
cc-hist | wl-copy         # Wayland — copy to clipboard
```

### Using cc-hist without replacing your `$EDITOR`

By default `install.sh` sets `EDITOR=cc-hist-edit` globally in Claude Code's `settings.json`, which means every `chat:externalEditor` action opens history search. If you want to keep your editor (e.g. `nvim`) and trigger history search via a **separate key binding**, do this instead:

**Step 1 — restore your original editor**

In `~/.claude/settings.json`, set `EDITOR` back to your editor and remove `cc-hist-edit`:

```json
{
  "env": {
    "EDITOR": "nvim"
  }
}
```

**Step 2 — add a dedicated history key binding**

Create a small wrapper script, e.g. `~/.local/bin/cc-hist-paste`:

```bash
#!/usr/bin/env bash
# Writes the selection directly to the Claude Code temp file passed as $1,
# falling back to stdout if called without an argument.
exec cc-hist --output "${1:-/dev/stdout}"
```

```bash
chmod +x ~/.local/bin/cc-hist-paste
```

**Step 3 — map it to a key in `~/.claude/keybindings.json`**

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

Then set `EDITOR=cc-hist-paste` only for the `ctrl+t` binding by pointing it at your wrapper, while keeping `EDITOR=nvim` as the default. Claude Code will call whichever binary is in `EDITOR` when `chat:externalEditor` fires — so having two bindings call the same action means you need two separate editor env vars, or a single smart wrapper:

```bash
#!/usr/bin/env bash
# ~/.local/bin/smart-editor
# If called with a file that already has content → open in nvim
# If the file is empty (Claude Code draft temp file) → open cc-hist
TMPFILE="${1:-}"
if [[ -n "$TMPFILE" && ! -s "$TMPFILE" ]]; then
    exec cc-hist --output "$TMPFILE"
else
    exec "${EDITOR_FALLBACK:-nvim}" "$TMPFILE"
fi
```

Set `EDITOR=smart-editor` in `~/.claude/settings.json` — empty temp files go to history search, non-empty files open in nvim.

## Uninstall

```bash
bash uninstall.sh
```

Removes the binaries and restores your original Claude Code `EDITOR` and keybindings.

## Data source

cc-hist reads `~/.claude/history.jsonl` — the same file Claude Code uses to populate its built-in history navigation. No conversation content, tool outputs, or assistant responses are read or transmitted anywhere; only user-typed messages are indexed.

## License

[BSD 2-Clause](LICENSE) © 2025 liks79
