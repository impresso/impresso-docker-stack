#!/usr/bin/env bash
# openrouter-usage.sh - show OpenRouter API key usage in a readable way.
#
# Usage:
#   ./openrouter-usage.sh              # reads OPENROUTER_API_KEY from ./.env
#   ./openrouter-usage.sh --dev        # reads it from ./.env.dev
#   ./openrouter-usage.sh -f path/to/file
#   ./openrouter-usage.sh --verbose    # also print the raw API response
#
# The key is looked up in the env file, then in the OPENROUTER_API_KEY
# environment variable; if neither has it, you are prompted for it.
#
# Requires: curl, jq

set -euo pipefail

# ---------- styling (disabled when not writing to a terminal) ----------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; CYAN=""
fi

die() { echo "${BOLD}${RED}Error:${RESET} $*" >&2; exit 1; }

# strips control characters (keeps tabs and newlines) from server-supplied text
sanitize() { LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'; }

# ---------- args ----------
ENV_FILE=".env"
VERBOSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dev) ENV_FILE=".env.dev"; shift ;;
    -f|--file) [[ $# -ge 2 ]] || die "$1 needs a path"; ENV_FILE="$2"; shift 2 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown argument: $1 (try --help)" ;;
  esac
done

command -v curl >/dev/null || die "curl is required"
command -v jq   >/dev/null || die "jq is required (brew install jq / apt install jq)"

# ---------- resolve key: env file -> environment -> prompt ----------
API_KEY=""
if [[ -f "$ENV_FILE" ]]; then
  # parsed, not sourced
  API_KEY=$(grep -E '^[[:space:]]*(export[[:space:]]+)?OPENROUTER_API_KEY=' "$ENV_FILE" \
    | tail -n1 \
    | tr -d '\r' \
    | sed -E "s/^[[:space:]]*(export[[:space:]]+)?OPENROUTER_API_KEY=//; s/^[\"']//; s/[\"'][[:space:]]*\$//" || true)
fi

if [[ -n "$API_KEY" ]]; then KEY_SOURCE="env file ($ENV_FILE)"; fi

if [[ -z "$API_KEY" && -n "${OPENROUTER_API_KEY:-}" ]]; then
  API_KEY="$OPENROUTER_API_KEY"
  KEY_SOURCE="env variable"
fi

if [[ -z "$API_KEY" ]]; then
  [[ -t 0 ]] || die "OPENROUTER_API_KEY not found in $ENV_FILE or environment, and no terminal to prompt on"
  read -r -s -p "Enter OpenRouter API key: " API_KEY
  echo
  [[ -n "$API_KEY" ]] || die "No API key provided"
  KEY_SOURCE="direct input"
fi

# ---------- helpers ----------
money() { # $1 = number or null
  if [[ "$1" == "null" || -z "$1" ]]; then echo "n/a"; else printf '$%.4f' "$1"; fi
}

bar() { # $1 = percent used (0-100)
  local pct=$1 width=30 filled color
  filled=$(awk -v p="$pct" -v w="$width" 'BEGIN{f=int(p*w/100+0.5); if(f>w)f=w; print f}')
  if   awk -v p="$pct" 'BEGIN{exit !(p>=90)}'; then color=$RED
  elif awk -v p="$pct" 'BEGIN{exit !(p>=70)}'; then color=$YELLOW
  else color=$GREEN; fi
  printf '%s' "$color"
  printf '%*s' "$filled" '' | tr ' ' '█'
  printf '%s%s' "$RESET$DIM" ''
  printf '%*s' "$((width - filled))" '' | tr ' ' '░'
  printf '%s' "$RESET"
}

row() { printf '  %s%-16s%s %s\n' "$BOLD" "$1" "$RESET" "$2"; }

# ---------- fetch key info ----------
out=$(curl -sS -w $'\n%{http_code}' "https://openrouter.ai/api/v1/key" \
      -K <(printf 'header = "Authorization: Bearer %s"\n' "$API_KEY")) || die "Request to /key failed"
HTTP_CODE="${out##*$'\n'}"
BODY="${out%$'\n'*}"
[[ "$HTTP_CODE" == "200" ]] || die "HTTP $HTTP_CODE from /key: $({ jq -r '.error.message // .' <<<"$BODY" 2>/dev/null || echo "$BODY"; } | sanitize)"

if [[ "$VERBOSE" == "1" ]]; then
  echo "${BOLD}${CYAN}Raw /key response${RESET} ${DIM}(HTTP $HTTP_CODE)${RESET}"
  { jq . <<<"$BODY" 2>/dev/null || echo "$BODY"; } | sanitize
  echo
fi

label=$(jq -r '.data.label // "n/a"' <<<"$BODY" | sanitize)
usage=$(jq -r '.data.usage // 0' <<<"$BODY")
limit=$(jq -r '.data.limit // "null"' <<<"$BODY")
remaining=$(jq -r '.data.limit_remaining // "null"' <<<"$BODY")
free=$(jq -r '.data.is_free_tier // false' <<<"$BODY")
daily=$(jq -r '.data.usage_daily // "null"' <<<"$BODY")
weekly=$(jq -r '.data.usage_weekly // "null"' <<<"$BODY")
monthly=$(jq -r '.data.usage_monthly // "null"' <<<"$BODY")

# effective_budget is the period-scoped spend the key limit applies to
eff_limit=$(jq -r '.data.effective_budget.limit_usd // "null"' <<<"$BODY")
budget_reset=""
if [[ "$eff_limit" != "null" ]]; then
  usage=$(jq -r '.data.effective_budget.spend_usd // 0' <<<"$BODY")
  limit=$eff_limit
  remaining=$(jq -r '.data.effective_budget.remaining_usd // "null"' <<<"$BODY")
  budget_reset=$(jq -r '.data.effective_budget.resets_at // ""' <<<"$BODY" | sanitize)
fi

# ---------- print ----------
echo
echo "${BOLD}${CYAN}OpenRouter API Key${RESET}  ${DIM}(${ENV_FILE})${RESET}"
echo "${DIM}──────────────────────────────────────────────${RESET}"
row "Label"      "$label"
row "Key source" "$KEY_SOURCE"
row "Free tier"  "$free"
row "Used"       "${BOLD}$(money "$usage")${RESET}"

if [[ "$limit" != "null" ]]; then
  pct=$(awk -v u="$usage" -v l="$limit" 'BEGIN{ if(l>0) printf "%.1f", u/l*100; else print 0 }')
  row "Limit"     "$(money "$limit")"
  row "Remaining" "${BOLD}$(money "$remaining")${RESET}"
  row "Consumed"  "$(bar "$pct") ${BOLD}${pct}%${RESET}"
else
  row "Limit"     "${DIM}unlimited${RESET}"
fi

if [[ -n "$budget_reset" ]]; then
  row "Resets" "${budget_reset%%T*}"
fi

if [[ "$daily" != "null" || "$weekly" != "null" || "$monthly" != "null" ]]; then
  echo
  echo "${BOLD}Recent usage${RESET}"
  row "Today"      "$(money "$daily")"
  row "This week"  "$(money "$weekly")"
  row "This month" "$(money "$monthly")"
fi
echo