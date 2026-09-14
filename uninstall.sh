#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/waveterm"
THEME_DIR="$CONFIG_DIR/termthemes"

echo "🧹 Uninstalling WaveTerm Clarity & Ocular Ergonomics Suite..."

# 1. Remove Custom Theme Files
echo "🗑️  Removing custom theme definitions..."
rm -f "$THEME_DIR/evidence-amber.json"
rm -f "$THEME_DIR/evidence-slate.json"
rm -f "$THEME_DIR/evidence-paper.json" 2>/dev/null || true
rm -f "$THEME_DIR/clarity-astigmatism.json" 2>/dev/null || true

# 2. Clean backgrounds.json & settings.json
echo "⚙️  Restoring WaveTerm configuration to defaults..."
python3 -c '
import json, os

config_dir = os.path.expanduser("~/.config/waveterm")

# 2a. Remove tab canvas preset
bg_file = os.path.join(config_dir, "backgrounds.json")
if os.path.exists(bg_file):
    try:
        with open(bg_file, "r") as f:
            bgs = json.load(f)
        bgs.pop("bg@amber-ochre", None)
        with open(bg_file, "w") as f:
            json.dump(bgs, f, indent=2)
        print("   ✓ Removed bg@amber-ochre from backgrounds.json")
    except Exception as e:
        print(f"   ⚠️ Could not update backgrounds.json: {e}")

# 2b. Clean settings.json overrides
s_file = os.path.join(config_dir, "settings.json")
if os.path.exists(s_file):
    try:
        with open(s_file, "r") as f:
            cfg = json.load(f)

        # Reset or remove Clarity-specific keys
        cfg.pop("term:theme", None)
        cfg.pop("tab:preset", None)
        cfg.pop("term:lineheight", None)
        cfg.pop("term:letterspacing", None)
        cfg.pop("term:fontweight", None)
        cfg.pop("term:fontweightbold", None)

        # Revert typography and transparency back to Wave default baselines
        cfg["term:fontsize"] = 12
        cfg["term:transparency"] = 0.5
        cfg["term:fontfamily"] = ""

        with open(s_file, "w") as f:
            json.dump(cfg, f, indent=2)
        print("   ✓ Restored default metrics in settings.json")
    except Exception as e:
        print(f"   ⚠️ Could not update settings.json: {e}")
'

# 3. Clean Shell Hooks from ~/.zshrc and ~/.bashrc
echo "🐚 Cleaning shell divider hooks and environment exports..."
python3 -c '
import os, re

targets = [os.path.expanduser("~/.zshrc"), os.path.expanduser("~/.bashrc")]
patterns = [
    r"# --- WaveTerm Clarity Dividers ---[\s\S]*?# --- End WaveTerm Clarity ---\n?",
    r"# --- Warp-style Command Divider ---[\s\S]*?# --- End Command Divider ---\n?",
    r"# Amber Ochre CLI Color Harmonization[\s\S]*?export BAT_THEME=\"gruvbox-dark\"\n?"
]

for rc in targets:
    if os.path.isfile(rc):
        with open(rc, "r") as f:
            content = f.read()
        cleaned = content
        for pat in patterns:
            cleaned = re.sub(pat, "", cleaned)
        if cleaned != content:
            with open(rc, "w") as f:
                f.write(cleaned.rstrip() + "\n")
            print(f"   ✓ Stripped Clarity hooks from {os.path.basename(rc)}")
'

# 4. Restart Backend Daemon
echo "🔄 Flushing WaveTerm backend daemon..."
pkill -9 -f "wavesrv|waveterm|wave" 2>/dev/null || true

echo ""
echo "✅ WaveTerm Clarity uninstalled successfully."
echo "👉 Restart Wave Terminal to load the default theme."
echo "👉 Reload your shell: source ~/.zshrc (or source ~/.bashrc)"
