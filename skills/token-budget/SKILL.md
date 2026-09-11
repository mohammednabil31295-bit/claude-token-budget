---
name: token-budget
description: Diagnose why a session's context filled up, cut the waste, and hand off to a fresh session without losing state. Use when context is filling faster than the task warrants, when a [context-budget] warning fires, before compaction, when the user asks why token usage went up, or when they ask how to make a session cheaper.
---

# Token budget

Context is a budget, not a resource that refills. This skill covers three jobs:
spend less by default, explain a spike when it happens, and restart cleanly when
a restart actually pays.

## 1. Spend less by default

Most waste is a handful of habits. These are cheap to fix and cost nothing when
the output would have been small anyway.

| Instead of | Do | Why |
|---|---|---|
| reading a whole file | `sed -n '40,80p' f.ts`, or Read with `offset`/`limit` | you needed 40 lines, not 4000 |
| `grep -r pattern .` | `grep -rn --include='*.ts' -m5 pattern src/` | scope the path, cap the matches |
| `find . -name '*.ts'` | `find src -name '*.ts' \| head -50` | unbounded trees are enormous |
| `git log` | `git log -n 20 --oneline` | full history is rarely the question |
| `npm install` / builds in foreground | redirect: `npm ci > /tmp/build.log 2>&1; tail -20 /tmp/build.log` | install logs are thousands of lines of noise |
| `cat package.json` | `jq -r '.scripts' package.json` | extract the field, not the file |
| re-reading a file to check an edit | trust the edit; it errors if it fails | the second read costs as much as the first |
| spawning a subagent to explore | search directly | each agent re-derives context you already hold |

Two more that matter as much as any command:

- **Do not re-derive settled facts.** If the session established which file owns
  a behavior, that answer is still good. Re-reading to "make sure" doubles the cost.
- **Do not carry a second task.** Unrelated work in the same session pays for the
  first task's context on every turn. Start it separately.

## 2. Explain a spike

When usage grows beyond what the task justifies, stop and report **before**
continuing. Name concrete causes with evidence, ranked by cost — never "the
conversation got long."

Look for: one huge tool output; the same file read twice; repeated failed
commands each echoing a full error; subagent fan-out; a heavy skill or MCP
schema loaded for a task that did not need it; scope drift into a second task.

Report as:

```
Cause                        Est. cost    Evidence
--------------------------------------------------------
<what happened>              ~<N> tokens  <where>
```

Then one line: **avoidable or not**, and what to do instead.

**Say so plainly when the spend was warranted.** A large task legitimately costs
a lot. Manufacturing a problem to look diligent wastes the user's attention and
trains them to ignore the warnings.

## 3. Restart only when it pays

A restart pays when most of the loaded context is dead weight — exploration,
dead ends, big outputs — and the remaining work needs only a small, statable
amount of state.

It does **not** pay when the loaded context is still live. Dropping state you
need costs more than the context you reclaim. Say "keep going" and mean it.

When a restart is warranted, write the handoff **before** the session ends:

```markdown
# Handoff — <task>

## Goal
<what the user wants, in their terms>

## State
- Done: <finished and verified>
- In progress: <half-done, and exactly where>
- Not started: <remaining>

## Key facts established
<decisions, constraints, values/IDs/paths that cost effort to find.
Not what re-reading a file would show.>

## Files that matter
- `path/to/file.ts:LINE` — why

## Dead ends
<tried and rejected, with the reason, so they are not retried>

## Next step
<the single concrete next action>

## Do not re-read
<already summarized above>
```

Under ~600 words. It is a briefing, not a transcript — if the handoff is as long
as the session, it has failed.

## Automatic signals

This plugin ships two hooks that supply evidence so the judgment above rests on
measurements rather than impressions:

- **PostToolUse** flags any tool result over ~25k characters (~6k tokens) with
  the size, the call, and a session running total. Silent below that.
  Tune with `CLAUDE_BIG_OUTPUT_CHARS`.
- **PreCompact** fires when context is full — the one reliable tripwire — listing
  the session's five largest outputs and prompting for the handoff before the
  conversation is compacted away.

A `[context-budget]` message reports size, not blame. Apply section 2 to it:
judge avoidability yourself, and stay silent when the cost was warranted.
