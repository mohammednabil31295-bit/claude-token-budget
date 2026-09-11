#!/usr/bin/env bash
# PreToolUse(Bash): refuse commands whose output is predictably huge and
# unbounded, handing back the cheap equivalent instead. Fails open.
set -uo pipefail

cmd=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("[token-guard] " + $r)
    }
  }'
  exit 0
}

# Already bounded? Let it through. This is the main false-positive guard.
if printf '%s' "$cmd" | grep -qE '\|[[:space:]]*(head|tail|wc|jq|cut)\b|>[[:space:]]*/|--max-count|(^|[[:space:]])-m[[:space:]0-9]|-maxdepth|--oneline|(^|[[:space:]])-n[[:space:]]*[0-9]'; then
  exit 0
fi

# Unscoped recursive grep over the whole tree
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*(grep|rg)\b.*(-r|-R|--recursive)' \
   && ! printf '%s' "$cmd" | grep -qE '\-\-include|\-\-glob|\-g[[:space:]]'; then
  deny "Unscoped recursive search — output is unbounded. Re-run with a path, a file filter and a match cap, e.g. grep -rn --include='*.ts' -m5 'pattern' src/"
fi

# find over the whole tree with no depth limit or cap
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*find[[:space:]]+(\.|/)([[:space:]]|$)'; then
  deny "Unbounded find — a full tree walk can return thousands of paths. Scope the directory and cap it, e.g. find src -maxdepth 3 -name '*.ts' | head -50"
fi

# git log with no limit
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*git[[:space:]]+log\b'; then
  deny "git log with no limit prints the whole history. Use git log -n 20 --oneline (add --stat or a path if you need detail)."
fi

# package installs / builds dumping thousands of lines into context
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*(npm|pnpm|yarn|bun)[[:space:]]+(install|ci|build|run[[:space:]]+build)|^[[:space:]]*pip[[:space:]]+install'; then
  deny "Install and build logs are thousands of lines. Redirect and read the tail: <cmd> > /tmp/build.log 2>&1; tail -20 /tmp/build.log"
fi

# cat on a file that is actually large
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*cat[[:space:]]+[^|;&]+$'; then
  f=$(printf '%s' "$cmd" | awk '{print $2}' | tr -d "'\"")
  if [ -f "$f" ]; then
    sz=$(wc -c < "$f" 2>/dev/null || echo 0)
    [ "$sz" -gt 20000 ] && deny "That file is $((sz/1000))KB — cat puts all of it in context. Read the part you need, e.g. sed -n '1,80p' $f, or jq for structured data."
  fi
fi

exit 0
