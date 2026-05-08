---
description: "Surface rising topics, killed ideas, and new links across a time window. Optional --audit flag for weekly-review output."
---

Read the `emerge` skill at `skills/emerge/SKILL.md`, then run the workflow. Flags: `--days N` (default 30), `--scope <path>` (restrict to a folder), `--min-cluster N` (default 3, clusters below this are treated as noise), `--audit` (non-interactive mode for the scheduled Sunday 9pm agent — writes to `01-Projects/VAULT/conversations/reports/emerge-YYYY-WW.md`), `--promote <pattern-id>` (skip mining and promote a previously-identified cluster to a full `03-Concepts/<slug>.md` note). The skill globs recently-modified files (capped at 500), extracts entities/concepts/tags/actions/sentiment markers, clusters semantically, names each cluster per Nate's anti-jargon naming DNA, scores + ranks, and reports the top 10.
