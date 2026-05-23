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

## Uninstall

```bash
bash uninstall.sh
```

Removes the binaries and restores your original Claude Code `EDITOR` and keybindings.

## Data source

cc-hist reads `~/.claude/history.jsonl` — the same file Claude Code uses to populate its built-in history navigation. No conversation content, tool outputs, or assistant responses are read or transmitted anywhere; only user-typed messages are indexed.

## License

[BSD 2-Clause](LICENSE) © 2025 liks79
