---
name: weekly
description: Friday 6:00 PM ET weekly review — runs /emerge --days 7 --audit, produces a week-in-review report covering new concepts, killed ideas, unresolved contradictions, and the rolling 7-day audit trend.
schedule: "0 18 * * 5 America/New_York"
plist: scheduled/launchd/io.lorecraft.mogging.weekly.plist
allowed-tools: Read, Write, Glob, Grep, Bash
writes:
  - 01-Conversations/VAULT/reports/weekly-YYYY-WW.md
reads:
  - 01-Conversations/VAULT/reports/audit-*.md
  - 01-Conversations/VAULT/reports/daily-*.md
  - 03-Concepts/**/*.md
  - 04-Index/**/*.md
  - Claude-Memory/lint-counter.json
---

# weekly — Friday 6pm ET week-in-review

Triggered by `scheduled/launchd/io.lorecraft.mogging.weekly.plist` at 18:00 America/New_York on Fridays. ISO week number format (`YYYY-WW`, e.g., `2026-15`) keeps weekly reports sortable across year boundaries.

## 1. Source gathering

Collect the past 7 days of signal:

1. `Glob` all `01-Conversations/VAULT/reports/daily-*.md` where date is within the last 7 days.
2. `Glob` all `01-Conversations/VAULT/reports/audit-*.md` within the same window.
3. `git log --since="7 days ago" --format="%h %s"` for a commit-level change list, filtered to commits starting with `[bot:wiki-add]`, `[bot:wiki-heal]`, or `[bot:save]`.
4. Read the current `Claude-Memory/lint-counter.json` + snapshot from 7 days ago (stored in `Claude-Memory/lint-counter-snapshots/YYYY-MM-DD.json` by the previous weekly run).

## 2. /emerge --days 7 --audit

Invoke the `emerge` skill in audit-only mode (no writes to concept notes — weekly agent is still read-only to the knowledge graph). `emerge` produces:

- **New concepts** committed this week with their inbound/outbound counts.
- **Killed ideas** — notes marked `status: archived` or deleted (detected via `git log --diff-filter=D`).
- **Contradictions surfaced** — pairs of concepts whose bodies disagree on a fact, detected by the `challenge` skill's contradiction index.
- **Rising topics** — tags that appeared ≥3 times this week vs. ≤1 time the prior week.
- **Declining topics** — tags that dropped ≥50% in weekly count.

## 3. Report output

Target: `01-Conversations/VAULT/reports/weekly-YYYY-WW.md`. Overwrite allowed — weekly runs own their file. Frontmatter:

```yaml
---
title: "Weekly Review — 2026-W15 (Apr 13–19)"
date: 2026-04-19
type: conversation
tags: [weekly, review, weekly-agent]
---
```

Body sections in this order:

1. **Top-of-mind** — the three highest-velocity topics from §2 rising, one line each.
2. **This week's shipments** — commits grouped by prefix (save / wiki-add / wiki-heal), with link counts.
3. **New concepts** — list of `[[wikilinks]]` with their lede sentence from frontmatter.
4. **Killed ideas** — deleted or archived, with the commit SHA that did the kill for recovery.
5. **Audit trend** — delta on each lint-counter category vs. 7 days ago (e.g., `dead_links: 812 → 784 (-28)`).
6. **Unresolved contradictions** — top 5 from the `challenge` index, with paths + one-line summary.

## 4. Snapshot rotation

After writing the weekly report, copy the current `Claude-Memory/lint-counter.json` to `Claude-Memory/lint-counter-snapshots/YYYY-MM-DD.json` so next week can diff against it. Keep only the last 13 weekly snapshots (one quarter); older snapshots get deleted.

## 5. Commit

Commit prefix: `[bot:wiki-heal]`. Subject: `[bot:wiki-heal] weekly review 2026-W15`.
