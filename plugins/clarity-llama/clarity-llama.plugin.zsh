# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil -*-
# clarity-llama - Ergonomic local LLM bridge for Wave Terminal

# Dynamic resolver: probes 127.0.0.1 on-demand with 150ms timeout
_clarity_resolve_llm() {
  local base_url="${CLARITY_LLM_URL:-${LLAMA_SERVER_URL:-${OPENAI_BASE_URL:-}}}"
  local api_key="${CLARITY_LLM_KEY:-${OPENAI_API_KEY:-sk-no-key-required}}"
  local model="${CLARITY_LLM_MODEL:-}"

  # Probe standard ports on 127.0.0.1 if no explicit URL is configured
  if [[ -z "$base_url" ]]; then
    local candidate_ports=("8080" "11434" "8000" "1234")
    for port in "${candidate_ports[@]}"; do
      if curl -s --connect-timeout 0.15 "[http://127.0.0.1](http://127.0.0.1):${port}/v1/models" >/dev/null 2>&1; then
        base_url="[http://127.0.0.1](http://127.0.0.1):${port}/v1"
        break
      fi
    done
  fi

  [[ -z "$base_url" ]] && return 1

  # Auto-detect loaded model name if omitted
  if [[ -z "$model" ]]; then
    model=$(curl -s --max-time 0.4 -H "Authorization: Bearer $api_key" "${base_url}/models" 2>/dev/null | python3 -c '
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

# Ctrl+G: Convert natural language into executable command in-place
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
    zle -M "⚠️ No local LLM found on 127.0.0.1 (probed ports 8080, 11434, 8000, 1234)"
    return
  fi

  local base_url="${endpoint_info%%|*}"
  local remaining="${endpoint_info#*|}"
  local api_key="${remaining%%|*}"
  local model="${remaining#*|}"

  local payload
  payload=$(python3 -c 'import json, sys; print(json.dumps({"model": sys.argv[1], "messages": [{"role": "system", "content": "You are a Linux CLI assistant. Output ONLY the raw executable command for the user prompt. No markdown, no explanations."}, {"role": "user", "content": sys.argv[2]}], "temperature": 0.1, "max_tokens": 120}))' "$model" "$prompt")

  local cmd
  cmd=$(curl -s --max-time 5 "${base_url}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_key" \
    -d "$payload" 2>/dev/null | python3 -c 'import sys, json; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())' 2>/dev/null)

  if [[ -n "$cmd" ]]; then
    BUFFER="$cmd"
    CURSOR=${#BUFFER}
  else
    BUFFER="$orig_buffer"
    zle -M "⚠️ Empty or invalid response from ${base_url}"
  fi
  zle redisplay
}

zle -N clarity-llama-nl2cmd
bindkey "^G" clarity-llama-nl2cmd

# Alt+E: Diagnose the last executed command without cluttering the screen
clarity-llama-diagnose() {
  local last_status=$?
  local last_cmd=$(fc -ln -1)

  local endpoint_info
  endpoint_info=$(_clarity_resolve_llm)
  if [[ $? -ne 0 || -z "$endpoint_info" ]]; then
    zle -M "⚠️ No local LLM running on 127.0.0.1 to diagnose failure"
    return
  fi

  local base_url="${endpoint_info%%|*}"
  local remaining="${endpoint_info#*|}"
  local api_key="${remaining%%|*}"
  local model="${remaining#*|}"

  print -P "\n%F{#b59654}── Local LLM Diagnosis ($base_url) ──%f"
  local payload
  payload=$(python3 -c 'import json, sys; print(json.dumps({"model": sys.argv[1], "messages": [{"role": "user", "content": f"Why did this Linux command fail with exit code {sys.argv[2]}? Command: {sys.argv[3]}. Provide a concise 2-sentence fix."}], "max_tokens": 120}))' "$model" "$last_status" "$last_cmd")

  local answer
  answer=$(curl -s --max-time 6 "${base_url}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_key" \
    -d "$payload" 2>/dev/null | python3 -c 'import sys, json; print(json.load(sys.stdin)["choices"][0]["message"]["content"].strip())' 2>/dev/null)

  if [[ -n "$answer" ]]; then
    print -P "%F{#baa98f}${answer}%f\n"
  else
    print -P "%F{#ab6259}Could not get diagnosis from local LLM.%f\n"
  fi
  zle redisplay
}

zle -N clarity-llama-diagnose
bindkey "\ee" clarity-llama-diagnose
