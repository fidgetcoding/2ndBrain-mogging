---
name: backfill
description: Scrape historical Claude Code JSONL session transcripts into the 2ndBrain vault as structured conversation notes. Handles inventory, per-session cost estimation, secret scrubbing, chunked summarization for large sessions, SHA-256 + embedding deduplication, and resumable batch runs. Routes output to `01-Conversations/{PROJECT}/YYYY-MM-DD-{slug}.md` using the same 8 signal types as `/save`.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# backfill — historical session ingestion

Pulls Claude Code session transcripts out of the local JSONL cache and materializes them as conversation notes in the vault, with the same signal-extraction schema as `/save` but run retroactively across weeks or months of history.

## Session source

Sessions live on disk at:

```
~/.claude/projects/<encoded-vault-path>/session-*.jsonl
```

Claude Code encodes the vault's absolute filesystem path into a project slug by replacing `/` with `-` and stripping the leading slash — e.g. a vault rooted at `/Users/<user>/Desktop/MyBrain` produces `~/.claude/projects/-Users-<user>-Desktop-MyBrain/`. The skill resolves this at runtime from the current working directory; never hard-code a specific project slug. Each file is a newline-delimited JSON transcript. Every line is one turn (user, assistant, tool result, etc.). Use `Glob` to enumerate; never load a session fully into memory before sizing it.

## Flags

| Flag | Purpose |
|------|---------|
| `--scan` | Inventory only: list sessions, byte size, line count, token estimate, cost estimate. No writes. |
| `--session <id>` | Process exactly one session by filename stem. |
| `--all --dry-run` | Process every session in memory, show what would be written, do not touch disk. |
| `--all --apply` | Full run. Requires explicit `yes` confirmation after cost display. |
| `--since YYYY-MM-DD` | Filter to sessions modified on/after this date (JSONL mtime). |
| `--resume` | Read `Claude-Memory/backfill-state.json`, skip already-completed session IDs, continue from the last incomplete one. |
| `--cost-cap N` | Abort mid-run if projected Haiku summarization cost exceeds N USD. Checked before each chunked-summarize call. |

`--scan`, `--apply`, `--dry-run`, and `--resume` are the primary combinations. `--since` and `--cost-cap` stack with any of them.

## Pipeline

### 1. Scan (inventory phase)

For every candidate JSONL:

- Stat the file (size, mtime).
- Stream-count lines with a bounded buffer (never `cat` the whole file).
- Estimate tokens: `bytes / 4` as a cheap upper bound, plus a role-weighted adjustment for tool-call payloads.
- Estimate cost: tokens at Haiku summarization rate for anything that will hit chunked-summarize; $0 for small sessions that get extracted directly.
- Emit one inventory row per session.

Print a total at the end: `N sessions | M tokens | ~$X.XX estimated`.

### 2. Per-session processing

For each session that clears the `--since` filter and is not already in `backfill-state.json`:

1. **Stream-read** the JSONL line-by-line. Parse incrementally; do not build the whole transcript in memory for large files.
2. **Size gate:**
   - `< 2,000 tokens` → **skip**. Signal density is too low to warrant a conversation note. Log as `skipped: tiny`.
   - `2,000–20,000 tokens` → **extract directly**. Feed the raw turns to the signal extractor without a summarization pass.
   - `> 20,000 tokens` → **chunked-summarize first**. Split at natural turn boundaries, summarize each chunk via Haiku (Tier 2), then feed the summarized transcript to the extractor.
3. **Security scrub BEFORE summarization.** Always run the scrub pass on raw transcript text *before* any sub-model call. Never feed secrets to Haiku (or any external model), even transiently. See Security below.
4. **Signal extraction.** Pull the same 8 signal types as `/save`:
   1. Decisions
   2. Tasks
   3. People
   4. Ideas
   5. Sources
   6. Insights
   7. Quotes
   8. Research conclusions
5. **Classification.** Load `Claude-Memory/aliases.yaml` (the `aliases` skill is the upstream producer). Route the session to a project by:
   - Direct `[[PROJECT]]` wikilinks found in the transcript.
   - Aliased entity mentions (`<PERSON-C>` → <ORG-B>/<PROJECT-A>, `<PERSON-H>` → MMA/<PROJECT-B>, etc.).
   - File-path cues (any edits inside `05-Projects/FOO/` → FOO).
   - Fallback: `MISC-CLAUDE`.
6. **Routing.** Write to `01-Conversations/{PROJECT}/YYYY-MM-DD-{slug}.md` where `YYYY-MM-DD` is the session's first-turn timestamp and `{slug}` is a 3–6 word kebab-case summary of the dominant topic.

### 3. Dedup

Before writing a new conversation note, check for duplicates in two passes:

1. **SHA-256 exact match.** Hash the normalized signal body. If any existing file under `01-Conversations/**` has the same hash, skip — the session is already captured.
2. **Embedding cosine ≥ 0.92.** Embed the new note's signal body. Compare against stored embeddings for existing conversation files. On cosine ≥ 0.92, treat as duplicate: append a `related:` link rather than create a second file.

Stash computed hashes + embeddings in `Claude-Memory/conversation-index.json` so dedup is cheap on subsequent runs.

### 4. Resume

Maintain `Claude-Memory/backfill-state.json`:

```json
{
  "version": 1,
  "last_run": "2026-04-16T18:00:00Z",
  "completed": ["session-abc123", "session-def456"],
  "in_progress": null,
  "errors": [{"session": "session-ghi789", "reason": "parse error line 1204"}]
}
```

Write this file after **every** session completes (success or error). On `--resume`, load the `completed` array and skip any listed IDs. An interrupted run restarts at the first non-completed session.

## Cost-gated apply

`--all --apply` must never run without confirmation. Before touching disk:

1. Run the full scan phase.
2. Print: `N sessions | M tokens | ~$X.XX estimated`.
3. Read from stdin. Require literal `yes` to proceed. Any other input aborts.

`--cost-cap` is checked *during* the run before each chunked-summarize call. Sessions that would push cumulative cost over the cap are deferred — logged to state with `reason: "cost-cap deferred"` and surfaced in the run summary.

## Rate limit

Process at most **20 concurrent sessions**. Use a bounded worker pool; queue the rest. Respect Haiku API rate limits — if a 429 comes back, back off exponentially and re-queue the affected session (do not mark it failed).

## Output

### Conversation notes

`01-Conversations/{PROJECT}/YYYY-MM-DD-{slug}.md`:

```markdown
---
title: "short topic summary"
date: 2026-04-16
type: conversation
source: session-abc123
project: <ORG-B>
tags: [backfilled]
related: [[<ORG-B>]]
---

## Summary
<2–4 sentence abstract>

## Decisions
- ...

## Tasks
- [ ] ...

## People
- [[<PERSON-C>]] — ...

## Ideas
...

## Sources
...

## Insights
...

## Quotes
> ...

## Research Conclusions
...
```

### Run log

`01-Conversations/backfill-log.md` gets one entry per session processed, appended chronologically:

```
- 2026-04-16 18:04 · session-abc123 · <ORG-B>/2026-04-13-<project-a>-pitch.md · extracted · 4.2k tokens · $0.0008
- 2026-04-16 18:04 · session-def456 · skipped: tiny (1.3k tokens)
- 2026-04-16 18:05 · session-ghi789 · <ORG-E>/2026-04-10-marketing-engagement.md · chunked-summarize · 42k tokens · $0.018
```

## Security

Run a regex scrub pass on every line **before** it leaves local context. Matches are replaced with `[REDACTED:<type>]`. Scrub list matches `/save`:

- `sk-ant-[A-Za-z0-9_-]+` — Anthropic API keys
- `ntn_[A-Za-z0-9_-]+` — Notion integration tokens
- `ghp_[A-Za-z0-9_-]+` — GitHub personal access tokens
- `AKIA[A-Z0-9]{16}` — AWS access keys
- `xox[abpr]-[A-Za-z0-9-]+` — Slack tokens
- Morgen API tokens (bearer patterns matching Morgen's token shape)
- Anything inside `.env`-style lines: `KEY=VALUE` where KEY matches `(SECRET|TOKEN|KEY|PASSWORD|PRIVATE)` case-insensitive

Scrubbing is **non-optional** and runs before summarization. A session that would have required Haiku but contains scrubbed content still uses the scrubbed text — never the raw text — for the model call. The scrub pre-empts any accidental exfiltration through the sub-model.

If a scrubbed token lands in the final conversation note, leave the `[REDACTED:<type>]` marker in place. Do not attempt to restore.

## Invariants

- Never write outside `01-Conversations/` or `Claude-Memory/`.
- Never delete source JSONL files.
- Never overwrite an existing conversation note without a dedup decision.
- Never run `--apply` without an explicit `yes` on the cost-gate prompt.
- Always flush `backfill-state.json` before exiting, even on error.
