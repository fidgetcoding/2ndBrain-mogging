---
description: "Bridge two notes — surfaces 3–5 structural analogies, transfer opportunities, or collision ideas between them. Read-only, terminal-only output, never writes."
---

Read the `connect` skill at `skills/connect/SKILL.md`, then run the workflow. Invocation is `/connect [[note-A]] [[note-B]] [--via [[intermediate]]] [--depth surface|deep]`. The skill resolves both wikilinks, scopes each note's neighborhood (backlinks, outgoing links, tag-overlap, folder-parent, frontmatter `related:`), finds overlap, and types each hit as `structural analogy`, `transfer opportunity`, or `collision idea` — capped at 5. HARD RULE: the skill is READ-ONLY. No `Write`, no `Edit`, no file creation, no `--save`, no commits. If the user wants to persist a connection, they copy-paste manually. The friction is the quality gate.
