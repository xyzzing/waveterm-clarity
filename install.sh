#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/xyzzing/waveterm-clarity/main"
WAVE_CONFIG="$HOME/.config/waveterm"
THEME_DIR="$WAVE_CONFIG/termthemes"
mkdir -p "$THEME_DIR"

echo "👁️  Installing WaveTerm Clarity & Ocular Ergonomics Suite..."

# 1. Automatic Font Installation (Medium weight & Atkinson Hyperlegible)
echo "📥 Checking and installing required high-acuity fonts..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$HOME/.local/share/fonts"
fi
mkdir -p "$FONT_DIR"

FONTS=(
  "JetBrainsMono-Medium.ttf:https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-Medium.ttf"
  "JetBrainsMono-Bold.ttf:https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-Bold.ttf"
)

for item in "${FONTS[@]}"; do
  NAME="${item%%:*}"
  URL="${item#*:}"
  if [ ! -f "$FONT_DIR/$NAME" ]; then
    echo "   Downloading $NAME..."
    curl -fsSL "$URL" -o "$FONT_DIR/$NAME" || true
  fi
done

if command -v fc-cache &>/dev/null; then
  fc-cache -f "$FONT_DIR" 2>/dev/null || true
fi

# 2. Download Themes
echo "🎨 Downloading calibrated terminal themes..."
curl -fsSL "$REPO_RAW/themes/terminal/evidence-amber.json" -o "$THEME_DIR/evidence-amber.json"
curl -fsSL "$REPO_RAW/themes/terminal/evidence-slate.json" -o "$THEME_DIR/evidence-slate.json"

# 3. Non-Destructive Update to Wave Configuration
python3 - << 'PYEOF'
import json, os

config_dir = os.path.expanduser("~/.config/waveterm")
os.makedirs(config_dir, exist_ok=True)

# Update backgrounds.json
bg_file = os.path.join(config_dir, "backgrounds.json")
bg_data = {}
if os.path.exists(bg_file):
    try:
        with open(bg_file, "r") as f: bg_data = json.load(f)
    except: pass
bg_data["bg@amber-ochre"] = {
    "display:name": "Amber Ochre Canvas",
    "display:order": 1,
    "bg:color": "#181614",
    "border:color": "#332e27"
}
with open(bg_file, "w") as f: json.dump(bg_data, f, indent=2)

# Non-destructive merge into settings.json
s_file = os.path.join(config_dir, "settings.json")
s_data = {}
if os.path.exists(s_file):
    try:
        with open(s_file, "r") as f: s_data = json.load(f)
    except: pass

s_data.update({
    "term:theme": "evidence-amber",
    "tab:preset": "bg@amber-ochre",
    "term:transparency": 0,
    "term:fontsize": 17,
    "term:lineheight": 1.45,
    "term:letterspacing": 1.2,
    "term:fontfamily": "'JetBrains Mono Medium', 'JetBrains Mono', monospace",
    "term:fontweight": "500",
    "term:fontweightbold": "700",
    "term:copyonselect": True
})
with open(s_file, "w") as f: json.dump(s_data, f, indent=2)
PYEOF

# 4. Universal Shell Integration (Zsh & Bash detection)
echo "🐚 Configuring command dividers and shell harmony..."
divider_code='
# --- WaveTerm Clarity Dividers ---
if [ -n "$ZSH_VERSION" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null
  precmd_clarity_divider() {
    local width=$(( COLUMNS > 1 ? COLUMNS - 1 : 80 ))
    print -P "%F{#5a5245}${(r:$width::─:)}%f"
  }
  add-zsh-hook -d precmd precmd_clarity_divider 2>/dev/null || true
  add-zsh-hook precmd precmd_clarity_divider 2>/dev/null || true
elif [ -n "$BASH_VERSION" ]; then
  draw_clarity_divider() {
    local cols=$(tput cols 2>/dev/null || echo 80)
    local width=$(( cols > 1 ? cols - 1 : 80 ))
    printf "\e[38;2;90;82;69m%*s\e[0m\n" "$width" "" | tr " " "─"
  }
  PROMPT_COMMAND="draw_clarity_divider${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
# --- End WaveTerm Clarity ---
'

TARGET_RC="$HOME/.zshrc"
[ ! -f "$TARGET_RC" ] && TARGET_RC="$HOME/.bashrc"

if [ -f "$TARGET_RC" ]; then
  if ! grep -q "WaveTerm Clarity Dividers" "$TARGET_RC"; then
    echo "$divider_code" >> "$TARGET_RC"
    echo "   Added session dividers to $(basename "$TARGET_RC")."
  fi
fi

# 5. Flush Daemon
pkill -9 -f "wavesrv|waveterm|wave" 2>/dev/null || true

echo ""
echo "✅ Installation complete!"
echo "👉 Restart Wave Terminal to load the new environment."
echo "👉 Run 'source $TARGET_RC' to activate command dividers."
