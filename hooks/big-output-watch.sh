#!/usr/bin/env bash
# PostToolUse: flag tool calls that return unusually large output, and keep a
# running per-session tally so the size of the spend can be reported concretely.
set -uo pipefail

THRESHOLD=${CLAUDE_BIG_OUTPUT_CHARS:-25000}   # ~6k tokens
STATE_DIR="$HOME/.claude/.context-budget"
mkdir -p "$STATE_DIR" 2>/dev/null

payload=$(cat)

read -r sid tool chars label <<<"$(printf '%s' "$payload" | jq -r '
  [ (.session_id // "unknown"),
    (.tool_name  // "unknown"),
    ((.tool_response | tostring) | length),
    ((.tool_input.command // .tool_input.file_path // .tool_input.pattern // "-")
      | tostring | gsub("[[:space:]]+"; " ") | .[0:80])
  ] | @tsv' 2>/dev/null | tr '\t' ' ')"

[ -z "${chars:-}" ] && exit 0
[ "$chars" -lt "$THRESHOLD" ] && exit 0

log="$STATE_DIR/$sid.log"
printf '%s\t%s\t%s\n' "$chars" "$tool" "$label" >> "$log"

total=$(awk -F'\t' '{s+=$1} END {print s+0}' "$log")
count=$(wc -l < "$log" | tr -d ' ')
tok=$((chars / 4)); tok_total=$((total / 4))

jq -n --arg t "$tool" --arg l "$label" \
      --argjson tok "$tok" --argjson tt "$tok_total" --argjson c "$count" '
{
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: (
      "[context-budget] That \($t) call returned ~\($tok) tokens (\($l)). " +
      "\($c) oversized call(s) this session, ~\($tt) tokens total. " +
      "Per the token budget rule in CLAUDE.md: if this was avoidable (unbounded search, " +
      "whole-file read, unscoped log), stop and tell the user the specific cause before " +
      "continuing. If it was necessary for the task, say nothing and carry on."
    )
  }
}'
