# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil -*-
# clarity-llama - Zero-touch local LLM bridge for Wave Terminal

clarity-smart-accept() {
  if [[ "$BUFFER" == \?* || "$BUFFER" == \#* ]]; then
    local raw="$BUFFER"
    local prompt="${raw#[?#]}"
    prompt="${prompt#"${prompt%%[![:space:]]*}"}"

    if [[ -z "$prompt" ]]; then
      zle .accept-line
      return
    fi

    POSTDISPLAY=""
    (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear

    zle -M "⏳ Asking local LLM..."
    zle -R

    local cmd
    cmd=$(python3 "$HOME/.zsh/clarity-llama/complete.py" "$prompt" 2>/dev/null)
    local ret=$?

    if [[ $ret -eq 0 && -n "$cmd" ]]; then
      POSTDISPLAY=""
      BUFFER="$cmd"
      CURSOR=$#BUFFER
      zle -M "✔ Command ready (press Enter to run)"
    else
      zle -M "⚠️ Local LLM failed to generate command"
    fi
    zle -R
  else
    zle .accept-line
  fi
}

zle -N accept-line clarity-smart-accept
zle -N clarity-smart-accept

clarity-llama-nl2cmd() {
  [[ -z "$BUFFER" ]] && return
  POSTDISPLAY=""
  (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
  zle -M "⏳ Asking local LLM..."
  zle -R

  local cmd
  cmd=$(python3 "$HOME/.zsh/clarity-llama/complete.py" "$BUFFER" 2>/dev/null)
  if [[ -n "$cmd" ]]; then
    POSTDISPLAY=""
    BUFFER="$cmd"
    CURSOR=$#BUFFER
    zle -M "✔ Command ready"
  else
    zle -M "⚠️ Local LLM failed"
  fi
  zle -R
}
zle -N clarity-llama-nl2cmd
bindkey "^G" clarity-llama-nl2cmd

clarity-llama-diagnose() {
  local last_status=$?
  local last_cmd=$(fc -ln -1)
  zle -M "⏳ Diagnosing with local LLM..."
  zle -R
  local diag
  diag=$(python3 "$HOME/.zsh/clarity-llama/diagnose.py" "$last_status" "$last_cmd" 2>/dev/null)
  if [[ -n "$diag" ]]; then
    print -P "\n%F{#b59654}── Local LLM Diagnosis ──%f\n%F{#baa98f}${diag}%f"
  else
    zle -M "⚠️ Diagnosis request failed"
  fi
  zle -R
}
zle -N clarity-llama-diagnose
bindkey "\ee" clarity-llama-diagnose
