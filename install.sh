#!/usr/bin/env bash
# install.sh — Install cc-hist and configure Claude Code integration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

KEYBINDINGS_FILE="$CLAUDE_HOME/keybindings.json"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"

info()    { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
ok()      { printf '\033[0;32m[ ok ]\033[0m  %s\n' "$*"; }
warn()    { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
die()     { printf '\033[0;31m[err ]\033[0m  %s\n' "$*" >&2; exit 1; }

echo ""
echo "  cc-hist — Claude Code History Fuzzy Searcher"
echo "  ============================================="
echo ""

# --- Dependency checks ---
for cmd in fzf python3; do
    command -v "$cmd" &>/dev/null || die "$cmd is required but not installed."
done
ok "Dependencies: fzf $(fzf --version | head -1), python3 found"

[[ -d "$CLAUDE_HOME" ]] || die "Claude Code data directory not found: $CLAUDE_HOME"
ok "Claude Code directory: $CLAUDE_HOME"

# --- Install binaries ---
mkdir -p "$INSTALL_DIR"

for script in cc-hist cc-hist-edit; do
    install -m 755 "$SCRIPT_DIR/bin/$script" "$INSTALL_DIR/$script"
    ok "Installed: $INSTALL_DIR/$script"
done

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    warn "$INSTALL_DIR is not in your PATH."
    warn "Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# --- Configure keybindings ---
info "Configuring Claude Code keybinding (Ctrl+T → history search)..."

python3 - "$KEYBINDINGS_FILE" <<'PYEOF'
import json, sys
from pathlib import Path

keybindings_file = Path(sys.argv[1])

if keybindings_file.exists():
    cfg = json.loads(keybindings_file.read_text())
else:
    cfg = {
        "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
        "bindings": []
    }

bindings = cfg.setdefault('bindings', [])

# Find or create Chat context block
chat = next((b for b in bindings if b.get('context') == 'Chat'), None)
if chat is None:
    chat = {'context': 'Chat', 'bindings': {}}
    bindings.append(chat)

existing = chat.setdefault('bindings', {})

# Add ctrl+t; also add ctrl+/ as alternative if not already mapped
added = []
for key in ['ctrl+t']:
    if key not in existing:
        existing[key] = 'chat:externalEditor'
        added.append(key)

keybindings_file.write_text(json.dumps(cfg, indent=2))

if added:
    print("Added keybinding(s): " + ", ".join(added))
else:
    print("Keybinding ctrl+t already configured.")
PYEOF

ok "Keybindings updated: $KEYBINDINGS_FILE"

# --- Configure Claude Code EDITOR ---
info "Setting Claude Code EDITOR to cc-hist-edit..."

CC_HIST_EDIT_PATH="$INSTALL_DIR/cc-hist-edit"

python3 - "$SETTINGS_FILE" "$CC_HIST_EDIT_PATH" <<'PYEOF'
import json, sys
from pathlib import Path

settings_file = Path(sys.argv[1])
cc_hist_edit = sys.argv[2]

cfg = json.loads(settings_file.read_text()) if settings_file.exists() else {}
env = cfg.setdefault('env', {})

original = env.get('EDITOR', '')
if original and original != cc_hist_edit:
    env['CC_FALLBACK_EDITOR'] = original
    print(f"Saved original editor as CC_FALLBACK_EDITOR: {original}")

env['EDITOR'] = cc_hist_edit
settings_file.write_text(json.dumps(cfg, indent=2))
print(f"EDITOR set to: {cc_hist_edit}")
PYEOF

ok "Claude Code settings updated: $SETTINGS_FILE"

echo ""
echo "  Installation complete!"
echo ""
echo "  Usage:"
echo "    In Claude Code : Press Ctrl+T to fuzzy search chat history"
echo "    In terminal    : cc-hist"
echo "    With output    : cc-hist -o /path/to/file"
echo ""
echo "  Note: The keybinding uses Claude Code's chat:externalEditor action."
echo "  If you had ctrl+g mapped to externalEditor with a different editor,"
echo "  that will now also open history search. Run uninstall.sh to revert."
echo ""
