---
name: health
description: Sunday 9:00 PM ET vault integrity check — verifies symlink resolution, Obsidian plugin loads, n8n sync freshness, and Morgen↔Obsidian task-count parity (within in-flight tolerance). Writes a one-line status plus a diagnostics block.
schedule: "0 21 * * 0 America/New_York"
plist: scheduled/launchd/io.<ORG-A>.mogging.health.plist
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__morgen__list_tasks, mcp__morgen__list_events
writes:
  - 01-Projects/VAULT/conversations/reports/health-YYYY-MM-DD.md
reads:
  - vault root symlinks
  - .obsidian/plugins/ (existence check only, no content read)
  - 05-Tasks/**/*.md (count only)
  - Morgen MCP (list_tasks, count)
  - n8n last execution timestamp (via n8n MCP or cached)
---

# health — Sunday 9pm ET vault integrity check

Triggered by `scheduled/launchd/io.<ORG-A>.mogging.health.plist` at 21:00 America/New_York on Sundays. The agent's job is signal-to-human: is the vault + sync + plugin pipeline healthy enough that the operator can trust Monday morning's data?

## 1. Checks (four gates)

### Gate A — Symlinks resolve

The live vault has a handful of project symlinks (e.g., the `05-Tasks/obsidian-tasks-sync` git submodule → a repo elsewhere on disk; or any repo submoduled under `01-Projects/<ORG-C>/GITHUB/<ORG-A>-REPOS/`). A broken symlink creates ghost paths in `Glob` output and confuses every downstream skill.

Check: `find <vault-root> -maxdepth 5 -type l` and `test -e` each target. Report count of broken vs. resolved.

### Gate B — Obsidian plugin loads

Check that critical plugins are present in `.obsidian/plugins/`:

- `obsidian-tasks-plugin` (Clare Macrae) — required for the task grammar in `references/wiki-schema.md` §5.
- `dataview` — required for several MOC query blocks.
- `templater` — required by the daily note template.

Existence check only — do NOT read plugin content (`.obsidian/**` is in the forbidden-paths list per wiki-schema.md §8). If a plugin directory is missing, flag it.

### Gate C — n8n sync freshness

Query the n8n MCP (or read the cached last-execution timestamp in `Claude-Memory/n8n-last-exec.json`) for the W1 workflow. Healthy: last successful execution was within the last 30 minutes (the polling window is 20m + 10m slack — the orchestrator `W0-Sync-Orchestrator` runs `Every 20 Minutes → W2 → W1`, so a healthy W1 commit lands at most every 20 minutes).

If stale: flag + suggest the user check the n8n dashboard. There's also an hourly `Sync-Health-Watchdog` workflow (`mzpCCbqD1MvxJhAm`) that auto-opens a GitHub issue + Telegram alert when the gap exceeds 60m — Gate C tightens that threshold for the weekly rollup.

### Gate D — Morgen ↔ Obsidian task-count parity

Pull the Morgen task count (`list_tasks` with `limit=500` per `reference_morgen_api_pagination`). Pull the Obsidian task count via `Grep -c` on `^- \[ \]` across `05-Tasks/**/*.md` plus an aggregated scan of inline tasks in the project subtrees.

The counts should match within ±5 (the in-flight tolerance covers tasks written to Obsidian in the last 15 minutes that haven't round-tripped through W1 to Morgen yet, per the operator's `feedback_task_state_source_of_truth` rule).

If the delta exceeds tolerance: flag the sync as drifting and include the top 10 UUIDs present in one side but not the other.

## 2. Report output

Target: `01-Projects/VAULT/conversations/reports/health-YYYY-MM-DD.md`. Overwrite allowed. Frontmatter:

```yaml
---
title: "Vault Health — 2026-04-19"
date: 2026-04-19
type: conversation
tags: [health, integrity, health-agent]
---
```

Body is structured so the first line is a glanceable one-liner — this is the value the operator gets from checking the report at a glance.

**First line (mandatory format):**

```
STATUS: OK | WARN | FAIL — <short summary, max 80 chars>
```

Example: `STATUS: WARN — Morgen/Obsidian task drift: 74 vs 68 (delta 6, tolerance ±5)`.

Following the status line, a diagnostics block with one `## Gate <A|B|C|D>` section per gate, containing pass/fail + detail.

## 3. Thresholds for WARN vs. FAIL

- **FAIL** if: Gate A has ≥1 broken symlink OR Gate B is missing obsidian-tasks-plugin OR Gate C is >90 minutes stale OR Gate D delta is >20.
- **WARN** if: Gate C is 30m–90m stale OR Gate D delta is 6–20 OR any informational plugin (dataview, templater) is missing.
- **OK** otherwise.

## 4. Commit

Commit prefix: `[bot:health]`. Subject format: `[bot:health] health 2026-04-19 — STATUS: <OK|WARN|FAIL>`. The status in the commit subject lets `git log --oneline` scan surface the trend without opening any file.
