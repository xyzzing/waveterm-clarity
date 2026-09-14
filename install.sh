#!/usr/bin/env bash
set -euo pipefail
REPO="https://raw.githubusercontent.com/xyzzing/waveterm-clarity/main"
DIR="$HOME/.config/waveterm"
mkdir -p "$DIR/termthemes"
echo "Deploying WaveTerm Clarity..."
curl -fsSL "$REPO/themes/terminal/evidence-amber.json" -o "$DIR/termthemes/evidence-amber.json"
curl -fsSL "$REPO/themes/terminal/evidence-slate.json" -o "$DIR/termthemes/evidence-slate.json"
python3 -c 'import json, os; p=os.path.expanduser("~/.config/waveterm/settings.json"); d=json.load(open(p)) if os.path.exists(p) else {}; d.update({"term:theme":"evidence-amber","tab:preset":"bg@amber-ochre","term:transparency":0,"term:fontsize":17,"term:lineheight":1.45,"term:letterspacing":1.2,"term:fontweight":"500","term:copyonselect":True}); json.dump(d, open(p,"w"), indent=2)'
pkill -9 -f "wavesrv|waveterm|wave" 2>/dev/null || true
echo "WaveTerm Clarity successfully installed!"
