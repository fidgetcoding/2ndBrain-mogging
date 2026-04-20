---
description: "Manage the alias classifier — add, edit, or audit entries in Claude-Memory/aliases.yaml with confidence-boost tuning."
---

Read the `aliases` skill at `skills/aliases/SKILL.md`, then run the workflow. Flags: `--bootstrap` (first-time population; emits to `Claude-Memory/aliases-pending.md` rather than overwriting an existing canonical `aliases.yaml`), `--suggest` (scan the last 14 days for new proper nouns, propose additions to `aliases-pending.md`), `--validate` (static-check for conflicts, duplicates, cycles, orphans, broken project paths — read-only), `--edit` (interactive edit session with per-section diffs), `--accept` (merge `aliases-pending.md` into `aliases.yaml` after backing up to `aliases.yaml.bak`). The file schema is mirrored in `skills/save/SKILL.md` §2.
