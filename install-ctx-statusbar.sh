#!/usr/bin/env bash
# install-ctx-statusbar.sh — Install the CTX status bar for Claude Code
#
# Shows: context window usage, tokens, cost, 5h/7d plan usage, model
# Works with Claude Pro/Max subscriptions on macOS and Linux
#
# Usage: bash install-ctx-statusbar.sh
#
# Example output:
#   CTX ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀  42% 84k/200k $1.23 │ 5h:7% 7d:8% opus-4-6
#
set -euo pipefail

echo "Installing ctx — Claude Code context window status bar..."
echo ""

# ── Check dependencies ────────────────────────────────────
missing=()
command -v jq &>/dev/null || missing+=("jq")
command -v curl &>/dev/null || missing+=("curl")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing required tools: ${missing[*]}"
    echo ""
    echo "Install them with:"
    echo "  brew install ${missing[*]}    (macOS)"
    echo "  apt install ${missing[*]}     (Linux)"
    exit 1
fi

# ── Install the script ──────────────────────────────────────
mkdir -p "$HOME/bin"

cat > "$HOME/bin/ctx" << 'CTXSCRIPT'
#!/usr/bin/env bash
# ctx — Claude Code Context Window Status Bar
# Shows: context %, tokens, cost, 5h/7d plan usage, model
# Reads session data from stdin (Claude Code statusLine JSON)
set -euo pipefail

# ── Read stdin JSON ─────────────────────────────────────────
INPUT=$(cat)

# ── Fetch Max plan usage (cached 60s) ───────────────────────
USAGE_CACHE="/tmp/ctx-usage-cache.json"
USAGE_CACHE_AGE="/tmp/ctx-usage-cache.age"
CACHE_TTL=60

fetch_usage() {
    local token=""

    # macOS: read from Keychain
    if command -v security &>/dev/null; then
        local creds
        creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
        if [[ -n "$creds" ]]; then
            token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || true)
        fi
    fi

    # Fallback: credentials file (Linux/WSL)
    if [[ -z "$token" && -f "$HOME/.claude/.credentials.json" ]]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null || true)
    fi

    if [[ -z "$token" ]]; then return 1; fi

    curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" > "$USAGE_CACHE" 2>/dev/null || return 1

    date +%s > "$USAGE_CACHE_AGE"
}

# Refresh cache if stale or missing
NEED_FETCH=1
if [[ -f "$USAGE_CACHE" && -f "$USAGE_CACHE_AGE" ]]; then
    CACHED_AT=$(cat "$USAGE_CACHE_AGE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    if (( NOW - CACHED_AT < CACHE_TTL )); then
        NEED_FETCH=0
    fi
fi
if (( NEED_FETCH )); then
    fetch_usage &>/dev/null || true
fi

# Parse usage data
USAGE_5H=""
USAGE_7D=""
if [[ -f "$USAGE_CACHE" ]]; then
    USAGE_5H=$(jq -r '.five_hour.utilization // empty' "$USAGE_CACHE" 2>/dev/null || true)
    USAGE_7D=$(jq -r '.seven_day.utilization // empty' "$USAGE_CACHE" 2>/dev/null || true)
fi

# ── Parse statusLine JSON fields ────────────────────────────
read -r USED_PCT TOTAL_TOKENS CTX_SIZE MODEL_ID PROJECT_DIR <<< "$(
    echo "$INPUT" | jq -r '[
        (.context_window.used_percentage // 0 | floor),
        (.context_window.total_input_tokens // 0),
        (.context_window.context_window_size // 200000),
        (.model.id // "unknown"),
        (.workspace.current_dir // "unknown")
    ] | @tsv' 2>/dev/null || echo "0 0 200000 unknown unknown"
)"

USED_PCT=${USED_PCT:-0}
TOTAL_TOKENS=${TOTAL_TOKENS:-0}
CTX_SIZE=${CTX_SIZE:-200000}
MODEL_ID=${MODEL_ID:-unknown}
PROJECT_DIR=${PROJECT_DIR:-unknown}

COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null || echo "0")

# ── Derive model display name ────────────────────────────────
MODEL=${MODEL_ID/claude-/}
MODEL=${MODEL%%-202*}

# ── Constants ───────────────────────────────────────────────
BAR_WIDTH=24

# ── ANSI Colors ─────────────────────────────────────────────
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
ITAL='\033[3m'
BLINK='\033[5m'
GREEN='\033[38;5;114m'
GREEN2='\033[38;5;72m'
YELLOW='\033[38;5;221m'
ORANGE='\033[38;5;208m'
RED='\033[38;5;203m'
CYAN2='\033[38;5;80m'
DGRAY='\033[38;5;236m'
LGRAY='\033[38;5;248m'

# Braille pixel chars (filled → dissolve → empty)
BFULL='⣿'
BD1='⣷'
BD2='⣶'
BD3='⣤'
BD4='⣀'

# ── Color helpers ───────────────────────────────────────────
pct_color() {
    local pct=$1
    if (( pct >= 90 )); then echo -ne "${RED}${BLINK}"
    elif (( pct >= 75 )); then echo -ne "${RED}"
    elif (( pct >= 55 )); then echo -ne "${ORANGE}"
    elif (( pct >= 40 )); then echo -ne "${YELLOW}"
    elif (( pct >= 20 )); then echo -ne "${GREEN}"
    else echo -ne "${GREEN2}"
    fi
}

pct_dim_color() {
    local pct=$1
    if (( pct >= 75 )); then echo -ne '\033[38;5;52m'
    elif (( pct >= 55 )); then echo -ne '\033[38;5;58m'
    elif (( pct >= 40 )); then echo -ne '\033[38;5;58m'
    else echo -ne '\033[38;5;236m'
    fi
}

usage_color() {
    local val=$1
    if (( val >= 90 )); then echo -ne "${RED}${BLINK}"
    elif (( val >= 75 )); then echo -ne "${RED}"
    elif (( val >= 50 )); then echo -ne "${ORANGE}"
    elif (( val >= 25 )); then echo -ne "${YELLOW}"
    else echo -ne "${GREEN}"
    fi
}

# ── Render progress bar ─────────────────────────────────────
render_bar() {
    local pct=$1 i
    local width=$BAR_WIDTH
    local total_units=$(( width * 4 ))
    local filled_units=$(( pct * total_units / 100 ))
    local full_chars=$(( filled_units / 4 ))
    local remainder=$(( filled_units % 4 ))
    local has_transition=0
    if (( remainder > 0 )); then has_transition=1; fi
    local empty_chars=$(( width - full_chars - has_transition ))

    local color
    color=$(pct_color "$pct")
    local dim_color
    dim_color=$(pct_dim_color "$pct")

    # Filled portion
    echo -ne "${color}"
    for ((i=0; i<full_chars; i++)); do echo -ne "${BFULL}"; done || true

    # Transition character (dissolve edge)
    if (( remainder > 0 )); then
        case $remainder in
            3) echo -ne "${BD1}" ;;
            2) echo -ne "${BD2}" ;;
            1) echo -ne "${BD3}" ;;
        esac
    fi
    echo -ne "${RST}"

    # Empty portion
    echo -ne "${dim_color}"
    for ((i=0; i<empty_chars; i++)); do echo -ne "${BD4}"; done || true
    echo -ne "${RST}"
}

# ── Format values ───────────────────────────────────────────
if (( USED_PCT > 100 )); then USED_PCT=100; fi

tokens_k="$(( TOTAL_TOKENS / 1000 ))k"
max_k="$(( CTX_SIZE / 1000 ))k"

pct_str=$(printf "%3d" "$USED_PCT")
color=$(pct_color "$USED_PCT")

COST_STR=$(printf '$%.2f' "$COST" 2>/dev/null || echo '$0.00')

# Format plan usage
USAGE_5H_STR=""
USAGE_7D_STR=""
if [[ -n "$USAGE_5H" ]]; then
    U5H=$(printf '%.0f' "$USAGE_5H" 2>/dev/null || echo "0")
    U5H_COLOR=$(usage_color "$U5H")
    USAGE_5H_STR="${LGRAY}5h:${RST}${U5H_COLOR}${U5H}%${RST}"
fi
if [[ -n "$USAGE_7D" ]]; then
    U7D=$(printf '%.0f' "$USAGE_7D" 2>/dev/null || echo "0")
    U7D_COLOR=$(usage_color "$U7D")
    USAGE_7D_STR="${LGRAY}7d:${RST}${U7D_COLOR}${U7D}%${RST}"
fi

# ── Render output ───────────────────────────────────────────
echo -ne " ${CYAN2}${BOLD}CTX${RST} "
render_bar "$USED_PCT"
echo -ne " ${color}${pct_str}%${RST}"
echo -ne " ${LGRAY}${tokens_k}/${max_k}${RST}"
echo -ne " ${YELLOW}${COST_STR}${RST}"
if [[ -n "$USAGE_5H_STR" || -n "$USAGE_7D_STR" ]]; then
    echo -ne " ${DGRAY}│${RST}"
    [[ -n "$USAGE_5H_STR" ]] && echo -ne " ${USAGE_5H_STR}"
    [[ -n "$USAGE_7D_STR" ]] && echo -ne " ${USAGE_7D_STR}"
fi
echo -ne " ${DGRAY}${ITAL}${MODEL}${RST}"
echo ""
CTXSCRIPT

chmod +x "$HOME/bin/ctx"
echo "  ✓ Installed ~/bin/ctx"

# ── Add ~/bin to PATH if needed ─────────────────────────────
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

if ! grep -q '$HOME/bin' "$SHELL_RC" 2>/dev/null; then
    echo '' >> "$SHELL_RC"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    echo "  ✓ Added ~/bin to PATH in $(basename "$SHELL_RC")"
else
    echo "  ✓ ~/bin already in PATH"
fi

# ── Configure Claude Code statusLine ────────────────────────
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if [[ -f "$SETTINGS_FILE" ]]; then
    TMP=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "~/bin/ctx"}}' "$SETTINGS_FILE" > "$TMP" 2>/dev/null && mv "$TMP" "$SETTINGS_FILE"
    echo "  ✓ Updated $SETTINGS_FILE"
else
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/bin/ctx"
  }
}
EOF
    echo "  ✓ Created $SETTINGS_FILE"
fi

# ── Done ────────────────────────────────────────────────────
echo ""
echo "Done! Restart Claude Code to see your status bar."
echo ""
echo "What you'll see:"
echo "  CTX ⣿⣿⣿⣿⣿⣀⣀⣀⣀⣀  42% 84k/200k \$1.23 │ 5h:7% 7d:8% opus-4-6"
echo ""
echo "  • Context window bar with color-coded fill (green → yellow → red)"
echo "  • Token count and cost for current session"
echo "  • 5-hour and 7-day plan usage (Pro/Max) with color coding"
echo "  • Active model name"
echo ""
echo "Plan usage updates every 60 seconds."
echo "Credentials are read from macOS Keychain or ~/.claude/.credentials.json."
