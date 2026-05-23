#!/usr/bin/env bash
# uninstall.sh — Remove cc-hist and restore Claude Code configuration
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

KEYBINDINGS_FILE="$CLAUDE_HOME/keybindings.json"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"

ok()  { printf '\033[0;32m[ ok ]\033[0m  %s\n' "$*"; }
info(){ printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }

echo ""
echo "  cc-hist — Uninstaller"
echo "  ====================="
echo ""

# --- Remove binaries ---
for script in cc-hist cc-hist-edit; do
    target="$INSTALL_DIR/$script"
    if [[ -f "$target" ]]; then
        rm "$target"
        ok "Removed: $target"
    else
        info "Not found (skipped): $target"
    fi
done

# --- Restore keybindings ---
if [[ -f "$KEYBINDINGS_FILE" ]]; then
    python3 - "$KEYBINDINGS_FILE" <<'PYEOF'
import json, sys
from pathlib import Path

f = Path(sys.argv[1])
cfg = json.loads(f.read_text())

removed = []
for binding in cfg.get('bindings', []):
    if binding.get('context') == 'Chat':
        bmap = binding.get('bindings', {})
        for key in ['ctrl+t']:
            if bmap.pop(key, None) is not None:
                removed.append(key)

f.write_text(json.dumps(cfg, indent=2))
if removed:
    print("Removed keybinding(s): " + ", ".join(removed))
else:
    print("No cc-hist keybindings found.")
PYEOF
    ok "Keybindings restored: $KEYBINDINGS_FILE"
fi

# --- Restore EDITOR in Claude Code settings ---
CC_HIST_EDIT_PATH="$INSTALL_DIR/cc-hist-edit"

if [[ -f "$SETTINGS_FILE" ]]; then
    python3 - "$SETTINGS_FILE" "$CC_HIST_EDIT_PATH" <<'PYEOF'
import json, sys
from pathlib import Path

f = Path(sys.argv[1])
cc_hist_edit = sys.argv[2]

cfg = json.loads(f.read_text())
env = cfg.get('env', {})

if env.get('EDITOR') == cc_hist_edit:
    fallback = env.pop('CC_FALLBACK_EDITOR', None)
    if fallback:
        env['EDITOR'] = fallback
        print(f"Restored EDITOR: {fallback}")
    else:
        env.pop('EDITOR', None)
        print("Removed EDITOR setting (was not set before install)")
    f.write_text(json.dumps(cfg, indent=2))
else:
    print("EDITOR was not set to cc-hist-edit, no change.")
PYEOF
    ok "Settings restored: $SETTINGS_FILE"
fi

echo ""
echo "  Uninstall complete."
echo ""
