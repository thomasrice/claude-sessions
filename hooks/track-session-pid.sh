#!/bin/bash
# Track session ID to terminal PID mapping for claude-sessions

# Read hook context from stdin
CONTEXT=$(cat)
SESSION_ID=$(echo "$CONTEXT" | jq -r '.session_id // empty')

if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Find terminal PID by walking up from current process
find_terminal_pid() {
    local pid=$$
    for _ in {1..15}; do
        [ "$pid" -le 1 ] && return 1
        local comm=$(cat /proc/$pid/comm 2>/dev/null)
        case "$comm" in
            alacritty|kitty|ghostty|foot|wezterm|gnome-terminal-*|konsole|xterm)
                echo "$pid"
                return 0
                ;;
        esac
        pid=$(awk '{print $4}' /proc/$pid/stat 2>/dev/null)
    done
    return 1
}

TERM_PID=$(find_terminal_pid)
if [ -z "$TERM_PID" ]; then
    exit 0
fi

# Write mapping to file (JSON format, one entry per line for easy parsing)
MAPPING_FILE="$HOME/.claude/session-pids.jsonl"
touch "$MAPPING_FILE"

# Remove any existing entry for this session or terminal (in case of restart)
grep -v "\"session_id\":\"$SESSION_ID\"" "$MAPPING_FILE" | grep -v "\"terminal_pid\":$TERM_PID" > "$MAPPING_FILE.tmp" 2>/dev/null || true
mv "$MAPPING_FILE.tmp" "$MAPPING_FILE" 2>/dev/null || true

# Add new mapping with timestamp
echo "{\"session_id\":\"$SESSION_ID\",\"terminal_pid\":$TERM_PID,\"timestamp\":$(date +%s)}" >> "$MAPPING_FILE"

# Simple cleanup: just keep last 100 entries
tail -100 "$MAPPING_FILE" > "$MAPPING_FILE.tmp" 2>/dev/null
mv "$MAPPING_FILE.tmp" "$MAPPING_FILE" 2>/dev/null || true

exit 0
