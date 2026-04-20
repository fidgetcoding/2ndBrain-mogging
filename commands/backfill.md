---
description: "Ingest historical Claude CLI session transcripts into the vault with chunked summarization, dedup, and resume-safe manifest."
---

Read the `backfill` skill at `skills/backfill/SKILL.md`, then run the workflow. The skill globs `~/.claude/projects/-2ndBrain/session-*.jsonl`, size-gates each session (<2k tokens skip; 2k–20k extract directly; >20k chunked-summarize via Haiku), security-scrubs BEFORE any sub-model call, extracts the 8 signal types `/save` uses, routes each session by alias+wikilink+file-path cues to `01-Conversations/{PROJECT}/YYYY-MM-DD-{slug}.md`, and dedupes by SHA-256 + embedding cosine ≥0.92. Flags: `--scan`, `--session <id>`, `--all --dry-run`, `--all --apply`, `--since YYYY-MM-DD`, `--resume` (reads `Claude-Memory/backfill-state.json`), `--cost-cap N`. Always prints a cost estimate before applying — no writes until user types `yes`.
