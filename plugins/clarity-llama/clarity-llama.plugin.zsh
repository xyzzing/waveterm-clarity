# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil -*-
# clarity-llama - Zero-touch local LLM bridge with AST safety gating & clean terminal redraw

_clarity_is_destructive() {
  local cmd="$1"
  if [[ "$cmd" =~ "(^|[;&|[:space:]])(rm|rmdir|mkfs|dd|truncate|shred)([[:space:]]|$)" ]] || \
     [[ "$cmd" =~ "(^|[[:space:]])-delete([[:space:]]|$)" ]] || \
     [[ "$cmd" =~ "(^|[[:space:]])>[[:space:]]*[^/]" ]] || \
     [[ "$cmd" =~ "git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|push[[:space:]]+.*--force)" ]] || \
     [[ "$cmd" =~ "chmod[[:space:]]+-[a-zA-Z]*R" ]]; then
    return 0
  fi
  return 1
}

clarity-smart-accept() {
  if [[ "$BUFFER" == \?\?* ]]; then
    local raw="$BUFFER"
    local prompt="${raw#\?\?}"
    prompt="${prompt#"${prompt%%[![:space:]]*}"}"
    [[ -z "$prompt" ]] && { zle .accept-line; return; }

    POSTDISPLAY=""
    (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
    zle -M "⏳ Querying & evaluating local LLM..."
    zle -R

    local cmd
    cmd=$(python3 "$HOME/.zsh/clarity-llama/complete.py" "$prompt" 2>/dev/null)
    if [[ -z "$cmd" ]]; then
      zle -M "⚠️ Local LLM failed to generate command"
      zle -R
      return
    fi

    # AST Safety Gate: fallback to buffer inspection if command is destructive
    if _clarity_is_destructive "$cmd"; then
      BUFFER="$cmd"
      CURSOR=$#BUFFER
      zle -M "⚠️ Destructive command detected — review before executing"
      zle reset-prompt
      return
    fi

    # Invalidate ZLE display so terminal cursor tracks output lines accurately
    zle -I

    print -P "%F{#b59654}── Running: $cmd ──%f"

    local stdout_file=$(mktemp)
    local stderr_file=$(mktemp)
    eval "$cmd" >"$stdout_file" 2>"$stderr_file"
    local ret=$?
    local out=$(<"$stdout_file")
    local err=$(<"$stderr_file")
    rm -f "$stdout_file" "$stderr_file"

    if [[ $ret -eq 0 ]]; then
      if [[ -n "$out" ]]; then
        print -r -- "$out"
      else
        print -P "%F{#9a8874}(0 results)%f"
      fi
      [[ -n "$err" ]] && print -P "%F{#ab6259}${err}%f"
    else
      print -P "%F{#ab6259}(command exited with code $ret)%f"
      [[ -n "$err" ]] && print -P "%F{#ab6259}${err}%f"
      [[ -n "$out" ]] && print -r -- "$out"
    fi

    BUFFER=""
    CURSOR=0
    POSTDISPLAY=""
    return

  elif [[ "$BUFFER" == \?* || "$BUFFER" == \#* ]]; then
    local raw="$BUFFER"
    local prompt="${raw#[?#]}"
    prompt="${prompt#"${prompt%%[![:space:]]*}"}"
    [[ -z "$prompt" ]] && { zle .accept-line; return; }

    POSTDISPLAY=""
    (( $+functions[_zsh_autosuggest_clear] )) && _zsh_autosuggest_clear
    zle -M "⏳ Asking local LLM..."
    zle -R

    local cmd
    cmd=$(python3 "$HOME/.zsh/clarity-llama/complete.py" "$prompt" 2>/dev/null)
    if [[ -n "$cmd" ]]; then
      POSTDISPLAY=""
      BUFFER="$cmd"
      CURSOR=$#BUFFER
      zle -M "✔ Command ready (press Enter to run)"
    else
      zle -M "⚠️ Local LLM failed to generate command"
    fi
    zle reset-prompt
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
  zle reset-prompt
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
  zle reset-prompt
}
zle -N clarity-llama-diagnose
bindkey "\ee" clarity-llama-diagnose
