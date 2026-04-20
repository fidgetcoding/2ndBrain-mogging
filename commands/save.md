---
description: "Capture a conversation, passage, dictated note, or ADR into the 2ndBrain vault with alias-driven classification and a mandatory dry-run preview."
---

Read the `save` skill at `skills/save/SKILL.md`, then run its workflow. Start by printing the five-option entry menu (1. Whole conversation · 2. Specific passage · 3. Dictated note · 4. ADR · 5. Exit) and wait for the user's number. All writes MUST pass through the alias classifier (`Claude-Memory/aliases.yaml`) and the §9 security scrub before hitting disk. Commit prefix is `[bot:save]` (backfill runs use `[bot:save --backfill]`). If the user supplies `--backfill` or `--auto` as arguments, honor those modes per the skill's §12 and §11.
