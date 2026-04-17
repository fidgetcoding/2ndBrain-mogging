---
description: "Capture a conversation, passage, dictated note, or ADR into the 2ndBrain vault with alias-driven classification and a mandatory dry-run preview."
---

Read the `save` skill at `skills/save/SKILL.md`, then run its workflow. Start by printing the four-branch entry menu (whole conversation · specific passage · dictated note · ADR) and wait for the user's number. All writes MUST pass through the alias classifier and sec<person-i>ty scrub defined in `references/wiki-schema.md` before hitting disk. Commit prefix is `[bot:save]`. If the user supplies `--backfill`, `--auto`, or `--from-stop` as arguments, honor those modes per the skill's §12 and §11.
