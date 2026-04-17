---
name: morning
description: Daily 8:00 AM ET briefing — pulls today's Morgen events, surfaces overdue/today tasks, and primes Claude-Memory/hot.md with the day's context window. Writes a single daily report; does NOT touch concept or source notes.
schedule: "0 8 * * * America/New_York"
plist: scheduled/launchd/io.lorecraft.mogging.morning.plist
allowed-tools: Read, Write, Edit, Glob, Bash
writes:
  - 01-Conversations/VAULT/reports/daily-YYYY-MM-DD.md
  - Claude-Memory/hot.md
reads:
  - 06-Tasks/**/*.md
  - Claude-Memory/aliases.yaml
  - Morgen MCP (list_events, list_tasks)
---

# morning — daily 8am ET briefing

Triggered by `scheduled/launchd/io.lorecraft.mogging.morning.plist` at 08:00 America/New_York. The agent has exactly two write targets and no others. Per `references/wiki-schema.md` §1, all reports live under `01-Conversations/VAULT/reports/`.

## 1. Pull today's Morgen state

Use the `morgen` MCP (Nathan's default calendar layer per memory rule "Morgen is Default"):

1. `list_events` with `start=<today 00:00 ET>` and `end=<today 23:59 ET>`. Include all-day events and timed events. Sort ascending by start time.
2. `list_tasks` filtered to overdue (due < today) AND today (due = today). Dedupe on 🆔 — Obsidian-synced tasks return under both Morgen task and event queries.

If the Morgen API returns HTTP 429 (rate limit), back off 30s and retry once. Second failure: write a degraded report flagging "Morgen unreachable — see cached state from yesterday" and continue.

## 2. Overdue surface

Cross-reference the overdue list with `06-Tasks/**/*.md` via `Grep` for `🆔 <uuid>`. For each overdue item:

- Source file path + line number.
- Task text, priority glyph, original due date, days overdue.
- Group by priority: 🔺 and ⏫ float to the top.

If the count exceeds 15, collapse the mid/low-priority section into a summary line (`+8 low-priority overdue — run /reflow_day to re-schedule`).

## 3. Write the daily report

Target: `01-Conversations/VAULT/reports/daily-YYYY-MM-DD.md`. Overwrite allowed (the report regenerates nightly). Frontmatter:

```yaml
---
title: "Daily Briefing — 2026-04-16"
date: 2026-04-16
type: conversation
tags: [daily, report, morning-agent]
---
```

Body sections in this order:

1. **Today's events** — timed list with Morgen event links.
2. **Overdue tasks** — grouped by priority, with wikilinks back to source files.
3. **Today's tasks** — due today, grouped by project alias.
4. **Weather signal** (optional) — from `Claude-Memory/hot.md` previous entry, not a fresh fetch.

## 4. Prime `Claude-Memory/hot.md`

`hot.md` is the short working-context file Nathan's other skills read at invocation to avoid cold starts. Prime it with:

- Top 5 overdue tasks (one line each, with UUID).
- Top 3 today events (title + start time).
- One-line "open threads" derived from the last 3 entries in `01-Conversations/VAULT/reports/daily-*.md`.

Keep `hot.md` under 2KB. Older entries roll off.

## 5. Commit

Commit prefix per `references/wiki-schema.md` §7: `[bot:wiki-heal]` (the morning briefing is classified as a healing pass since it's idempotent and edits-in-place). Commit subject: `[bot:wiki-heal] morning briefing 2026-04-16`.
