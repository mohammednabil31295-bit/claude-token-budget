#!/usr/bin/env bash
# PreCompact: context is full. Surface what drove it and require a handoff summary.
set -uo pipefail
STATE_DIR="$HOME/.claude/.context-budget"
payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "unknown"' 2>/dev/null)
trigger=$(printf '%s' "$payload" | jq -r '.trigger // "auto"' 2>/dev/null)
log="$STATE_DIR/$sid.log"

if [ -s "$log" ]; then
  top=$(sort -rn "$log" | head -5 | awk -F'\t' '{printf "  ~%d tok  %s  %s\n", $1/4, $2, $3}')
  total=$(awk -F'\t' '{s+=$1} END {printf "%d", s/4}' "$log")
  detail="Biggest tool outputs this session:"$'\n'"$top"$'\n'"Oversized calls totalled ~${total} tokens."
else
  detail="No single oversized tool output was recorded — the context filled from accumulated conversation, not one big call."
fi

jq -n --arg d "$detail" --arg tr "$trigger" '
{
  systemMessage: "Context full (\($tr) compact). Claude was asked to explain the cause and write a handoff.",
  hookSpecificOutput: {
    hookEventName: "PreCompact",
    additionalContext: (
      "[context-budget] Context is full; a \($tr) compaction is about to run.\n\n" + $d +
      "\n\nBefore continuing, follow the token budget rule in CLAUDE.md: tell the user " +
      "the specific reasons usage grew, whether they were avoidable, and — if a fresh " +
      "session would genuinely help — write the handoff summary now (goal, done / " +
      "in progress / remaining, key facts, files with line numbers, dead ends, next step, " +
      "what not to re-read) so it survives the compaction."
    )
  }
}'
