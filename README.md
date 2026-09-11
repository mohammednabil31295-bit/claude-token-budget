# token-budget

A Claude Code plugin that catches runaway context spend, explains the cause with
evidence, and hands off cleanly to a fresh session.

Claude Code has no built-in tripwire for token usage. This adds one.

## What it does

**Measures.** A `PostToolUse` hook flags any tool result over ~25k characters
(~6k tokens) with its size, the call that produced it, and a session running
total. Silent below the threshold.

**Catches the wall.** A `PreCompact` hook fires the moment context fills — the
one reliable signal — listing the session's five largest outputs and prompting
for a handoff summary before the conversation is compacted away.

**Judges.** The `token-budget` skill turns those measurements into an answer:
which calls cost what, whether it was avoidable, and whether a restart actually
pays. It is explicit that a large task legitimately costs a lot, and says so
rather than inventing a problem.

**Hands off.** The `context-budget-auditor` agent writes a self-contained
briefing — goal, state, key facts, files with line numbers, dead ends already
tried, next step — so a fresh session continues without re-deriving anything.

## Install

```
/plugin marketplace add <your-github-username>/claude-token-budget
/plugin install token-budget@token-budget-marketplace
```

Restart Claude Code afterwards — the settings watcher only picks up hooks from
directories that had a settings file when the session started.

## Configure

| | |
|---|---|
| `CLAUDE_BIG_OUTPUT_CHARS` | size threshold in characters (default `25000`) |
| disable | `/plugin uninstall token-budget@token-budget-marketplace` |

## What it does not do

There is no hook that fires at a percentage of context — only at full. Mid-session
catching therefore depends on the `PostToolUse` signal, which sees individual
tool results, not the conversation's total size. The hooks measure; the judgment
of whether a cost was avoidable is Claude's, and Claude's estimate of consumed
context is approximate.

## Licence

MIT
