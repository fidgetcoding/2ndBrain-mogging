---
description: "Ingest historical Claude CLI session transcripts into the vault with chunked summarization, dedup, and resume-safe manifest."
---

Read the `backfill` skill at `skills/backfill/SKILL.md`, then run the workflow. The skill globs `~/.claude/projects/<project>/session-*.jsonl`, chunked-summarizes each session above 20k tokens, dedupes by SHA-256 + embedding similarity (≥0.92), and appends to `Claude-Memory/backfill-manifest.jsonl`. Always prints a cost estimate before applying — no writes until user types `y`. Supports `--resume` for kill-9 recovery and `--include-tools` for tool-call capture. Commit prefix `[bot:backfill]`. Rules in `references/wiki-schema.md` bind all writes.
