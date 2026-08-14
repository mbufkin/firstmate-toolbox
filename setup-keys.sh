#!/usr/bin/env bash
# setup-keys.sh - the only manual step after a fresh-machine bootstrap.
# Adds your provider API keys to Pi's credential store (~/.pi/agent/auth.json,
# mode 0600). Pi reads them for every crewmate / secondmate / primary launch.
#
#   ./setup-keys.sh
#
# Providers that support a subscription (/login) inside Pi don't need a key.
set -euo pipefail

AUTH_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
AUTH_FILE="$AUTH_DIR/auth.json"

# ordered list of provider ids -> pretty name
PROVIDER_IDS=(anthropic openai google groq openrouter xai deepseek mistral cerebras together opencode nvidia kimi-coding)
declare -A PROVIDER_NAMES=(
  [anthropic]="Anthropic"
  [openai]="OpenAI"
  [google]="Google Gemini"
  [groq]="Groq"
  [openrouter]="OpenRouter"
  [xai]="xAI"
  [deepseek]="DeepSeek"
  [mistral]="Mistral"
  [cerebras]="Cerebras"
  [together]="Together AI"
  [opencode]="OpenCode Zen"
  [nvidia]="NVIDIA NIM"
  [kimi-coding]="Kimi for Coding"
)

command -v jq >/dev/null 2>&1 || {
  echo "error: jq is required (installed by bootstrap.sh)" >&2
  exit 1
}

current='{}'
if [[ -f "$AUTH_FILE" ]]; then
  current=$(jq -c . "$AUTH_FILE" 2>/dev/null || printf '{}')
fi

save() {
  mkdir -p "$AUTH_DIR"
  printf '%s\n' "$current" | jq . > "$AUTH_FILE"
  chmod 600 "$AUTH_FILE"
}

has_key() {
  jq -e ".[\"$1\"]?.key and (.[\"$1\"]?.key|length>0)" <<<"$current" >/dev/null 2>&1
}

show_status() {
  local i=1 p
  printf '\nCurrent Pi API keys (%s):\n' "$AUTH_FILE"
  for p in "${PROVIDER_IDS[@]}"; do
    if has_key "$p"; then
      printf '  %2d) %-18s \033[32mset\033[0m\n' "$i" "${PROVIDER_NAMES[$p]}"
    else
      printf '  %2d) %-18s \033[90mnot set\033[0m\n' "$i" "${PROVIDER_NAMES[$p]}"
    fi
    ((i++))
  done
  printf '  %2d) show / hide secret values\n' "$((i))"
  printf '  q)  done\n'
}

set_key() {
  local p="$1" key
  read -r -p "  ${PROVIDER_NAMES[$p]} key (enter to skip): " -s key
  printf '\n'
  [[ -z "$key" ]] && return
  current=$(jq --arg p "$p" --arg k "$key" '.[$p]={type:"api_key",key:$k}' <<<"$current")
  save
  printf '  \033[32m%s saved.\033[0m\n' "${PROVIDER_NAMES[$p]}"
}

reveal() {
  local i=1 p v
  for p in "${PROVIDER_IDS[@]}"; do
    v=$(jq -r ".[\"$p\"]?.key // empty" <<<"$current" 2>/dev/null)
    printf '  %2d) %-18s %s\n' "$i" "${PROVIDER_NAMES[$p]}" "${v:-(empty)}"
    ((i++))
  done
}

echo "== firstmate-toolbox :: add API keys =="
echo "Keys are written to $AUTH_FILE (0600)."
if command -v pi >/dev/null 2>&1 && [[ -f "$AUTH_FILE" ]]; then
  echo "Existing keys are kept; adding or editing a provider overwrites just that provider."
fi

while true; do
  show_status
  read -r -p "  add a key for #, r to reveal, q to quit: " n || true
  case "$n" in
    q|Q|"") echo; echo "Done. Launch it with: firstmate"; break ;;
    r|R) reveal ;;
    *)
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#PROVIDER_IDS[@]} )); then
        set_key "${PROVIDER_IDS[$((n-1))]}"
      else
        echo "  invalid choice"
      fi
      ;;
  esac
done
