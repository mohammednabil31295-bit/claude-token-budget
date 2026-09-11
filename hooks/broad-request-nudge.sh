#!/usr/bin/env bash
# UserPromptSubmit: when a request is phrased in a way that implies scanning
# everything, require a scoped plan + confirmation before the expensive work.
# Never blocks the prompt — the user's intent stands; only the approach is checked.
set -uo pipefail

p=$(cat | jq -r '.prompt // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
[ -z "$p" ] && exit 0

pat='(read|scan|review|analy[sz]e|check|go through|look at|audit|refactor|document|summari[sz]e)[[:space:]]+(the[[:space:]]+)?(whole|entire|all|every|complete|full)|(whole|entire|complete|full)[[:space:]]+(codebase|repo|repository|project|code ?base|system)|every[[:space:]]+(file|function|component|table|endpoint)|all[[:space:]]+(the[[:space:]]+)?files'

printf '%s' "$p" | grep -qE "$pat" || exit 0

jq -n '{
  systemMessage: "[token-guard] Broad-scope request — Claude was asked to propose a scoped approach first.",
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: (
      "[token-guard] This request is phrased to cover everything, which is the most " +
      "expensive shape a task can take. Before doing it the broad way:\n" +
      "1. Say what the exhaustive version would actually cost (rough file/token scale).\n" +
      "2. Offer a scoped alternative that answers the real question — a representative " +
      "sample, the highest-risk subset, a structural pass before a deep one, or a " +
      "targeted search instead of a full read.\n" +
      "3. Ask which they want, in one line, and wait.\n" +
      "If the exhaustive version is genuinely the right call — the task is small, or " +
      "completeness is the point — say so plainly and just do it. Do not stall a " +
      "cheap task with a cost discussion."
    )
  }
}'
