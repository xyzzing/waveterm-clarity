# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil -*-
# clarity-llama.plugin.zsh - Zero-touch Local LLM Bridge for Wave Terminal

_clarity_resolve_llm() {
  local base_url="${CLARITY_LLM_URL:-${OPENAI_BASE_URL:-}}"
  local api_key="${CLARITY_LLM_KEY:-${OPENAI_API_KEY:-sk-no-key-required}}"
  local model="${CLARITY_LLM_MODEL:-}"

  if [[ -z "$base_url" ]]; then
    local candidate_ports=("11434" "8000" "8080" "1234")
    for port in "${candidate_ports[@]}"; do
      if curl -s --connect-timeout 0.15 "http://127.0.0.1:${port}/v1/models" >/dev/null 2>&1; then
        base_url="http://127.0.0.1:${port}/v1"
        break
      fi
    done
  fi

  [[ -z "$base_url" ]] && return 1

  if [[ -z "$model" ]]; then
    model=$(curl -s --max-time 0.5 -H "Authorization: Bearer $api_key" "${base_url}/models" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    models = data.get("data", [])
    if models:
        print(models[0].get("id", ""))
except Exception:
    pass
' 2>/dev/null)
  fi

  echo "${base_url}|${api_key}|${model:-default}"
}

clarity-llama-nl2cmd() {
  local prompt="$BUFFER"
  [[ -z "$prompt" ]] && return

  local orig_buffer="$BUFFER"
  BUFFER="⏳ Querying local LLM..."
  zle redisplay

  local endpoint_info
  endpoint_info=$(_clarity_resolve_llm)
  if [[ $? -ne 0 || -z "$endpoint_info" ]]; then
    BUFFER="$orig_buffer"
    print -P "\n%F{#ab6259}⚠️ No active local LLM detected (probed ports 11434, 8000, 8080, 1234).%f"
    zle redisplay
    return
  fi

  local base_url="${endpoint_info%%|*}"
  local remaining="${endpoint_info#*|}"
  local api_key="${remaining%%|*}"
  local model="${remaining#*|}"

  local payload
  payload=$(python3 -c 'import json, sys; print(json.dumps({"model": sys.argv[1], "messages": [{"role": "system", "content": "You are a Linux CLI assistant. Output ONLY the raw shell command for the user prompt. No markdown, no backticks, no explanation."}, {"role": "user", "content": sys.argv[2]}], "temperature": 0.1, "max_tokens": 120}))' "$model" "$prompt")

  local cmd
  cmd=$(curl -s --max-time 4 "${base_url}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_key" \
    -d "$payload" 2>/dev/null | python3 -c 'import sys, json; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())' 2>/dev/null)

  if [[ -n "$cmd" ]]; then
    BUFFER="$cmd"
    CURSOR=${#BUFFER}
  else
    BUFFER="$orig_buffer"
  fi
  zle redisplay
}

zle -N clarity-llama-nl2cmd
bindkey "^G" clarity-llama-nl2cmd

clarity-llama-precmd() {
  local last_status=$?
  if [[ $last_status -ne 0 && $last_status -ne 130 ]]; then
    local last_cmd=$(fc -ln -1)
    print -P "%F{#ab6259}Command failed ($last_status). Press Alt+E to diagnose with active LLM.%f"

    _clarity_diagnose() {
      local endpoint_info
      endpoint_info=$(_clarity_resolve_llm)
      [[ -z "$endpoint_info" ]] && return

      local base_url="${endpoint_info%%|*}"
      local remaining="${endpoint_info#*|}"
      local api_key="${remaining%%|*}"
      local model="${remaining#*|}"

      print -P "%F{#b59654}── Local LLM Diagnosis ($model @ $base_url) ──%f"
      local payload
      payload=$(python3 -c 'import json, sys; print(json.dumps({"model": sys.argv[1], "messages": [{"role": "user", "content": f"Why did this Linux command fail with code {sys.argv[2]}? Command: {sys.argv[3]}. Give a concise 2-sentence fix."}], "max_tokens": 120}))' "$model" "$last_status" "$last_cmd")

      curl -s --max-time 6 "${base_url}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" 2>/dev/null | \
        python3 -c 'import sys, json; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())' 2>/dev/null || echo "Request failed."
    }
    zle -N _clarity_diagnose
    bindkey "\ee" _clarity_diagnose
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd clarity-llama-precmd
