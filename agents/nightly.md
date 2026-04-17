---
name: nightly
description: Nightly 10:00 PM ET vault audit — AUDIT-ONLY, no writes to concept or source notes. Runs /wiki audit scoped to 02-Sources, 03-Concepts, and 04-Index. Appends the report to the daily audit log and increments the lint counter.
schedule: "0 22 * * * America/New_York"
plist: scheduled/launchd/io.lorecraft.mogging.nightly.plist
allowed-tools: Read, Write, Glob, Grep, Bash
writes:
  - 01-Conversations/VAULT/reports/audit-YYYY-MM-DD.md
  - Claude-Memory/lint-counter.json
reads:
  - 02-Sources/**/*.md
  - 03-Concepts/**/*.md
  - 04-Index/**/*.md
---

# nightly — audit-only report at 10pm ET

Triggered by `scheduled/launchd/io.lorecraft.mogging.nightly.plist` at 22:00 America/New_York. The hard contract: **no writes to any note under 02-Sources, 03-Concepts, or 04-Index.** The only writes are the audit report itself and the lint-counter. This separation is the reason the agent is safe to schedule unattended.

## 1. Scope

Audit surface is exactly three folders: `02-Sources/`, `03-Concepts/`, `04-Index/`. Everything else is out of scope — conversations, projects, tasks, and Claude-Memory are audited by other agents or by `/health` on Sundays.

Audit is the same inspection logic as `/wiki audit` — call the `wiki` skill with `--audit --no-fix --scope=02-03-04`. The skill MUST NOT enter its write paths.

## 2. Checks performed

Per `references/wiki-schema.md` §3 and §4:

1. **Dead wikilinks.** Any `[[target]]` whose target file does not exist in the vault.
2. **Orphan concepts.** Any note in `03-Concepts/` with zero inbound links from `02-Sources/` OR zero outbound links to `04-Index/`.
3. **Missing frontmatter.** Any file missing the universal 5 keys (title, date, type, tags, aliases) or the per-type required fields.
4. **Stale concepts.** Any `03-Concepts/` note where `last_confirmed` is > 180 days ago AND `owner: llm`. Human-owned stale notes are informational-only; LLM-owned stale notes are auto-flagged for re-confirmation.
5. **MOC coverage.** Any concept not listed in at least one `04-Index/MOC-*.md`.
6. **Ambiguous-routing unresolved.** Any file tagged `#ambiguous-routing` older than 30 days where the stub still exists — prompts human to resolve the 50/50.

Each check produces a list of file-level findings with exact paths and line numbers.

## 3. Report output

Target: `01-Conversations/VAULT/reports/audit-YYYY-MM-DD.md`. **Append mode** — if the file exists, append a new `## Run <timestamp>` section. This lets multiple audit passes in one day coexist.

Frontmatter (only on file creation):

```yaml
---
title: "Nightly Audit — 2026-04-16"
date: 2026-04-16
type: conversation
tags: [audit, nightly-agent]
---
```

Body for each run: one section per check, counts + top 20 findings per check. If a check has zero findings, the section reads `zero findings` on one line — don't omit the section entirely (absence is a signal).

## 4. Lint counter

Increment `Claude-Memory/lint-counter.json`:

```json
{
  "runs": 147,
  "last_run": "2026-04-16T22:00:00-04:00",
  "findings_by_check": {
    "dead_links": 812,
    "orphan_concepts": 34,
    "missing_frontmatter": 12,
    "stale_concepts": 56,
    "moc_coverage": 8,
    "ambiguous_unresolved": 3
  }
}
```

The counter is append-semantic on totals — findings_by_check accumulates across all runs so trend analysis (via `/emerge --days 7`) can diff week-over-week.

## 5. Commit

Commit prefix: `[bot:wiki-heal]`. Subject: `[bot:wiki-heal] nightly audit 2026-04-16 — N findings`. If findings total is zero across all checks, still commit (the zero is evidence the vault is clean).
