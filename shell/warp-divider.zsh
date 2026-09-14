autoload -Uz add-zsh-hook
function precmd_warp_divider() {
  local width=$(( COLUMNS > 1 ? COLUMNS - 1 : 80 ))
  print -P "%F{#5a5245}${(r:$width::─:)}%f"
}
add-zsh-hook -d precmd precmd_warp_divider 2>/dev/null
add-zsh-hook precmd precmd_warp_divider
