---
description: "Repair orphaned notes and bidirectionally link projects, sub-projects, MOCs, and hubs — closes broken graph bridges."
---

Read the `tether` skill at `skills/tether/SKILL.md`, then run the workflow. Per `references/wiki-schema.md` §1 and §3, the skill finds orphan concepts (zero inbound or zero outbound), renames legacy `*-Index.md` files to match folder names, adds missing entries to `04-Index/MOC-*.md`, and ensures every `05-Projects/<ORG>/<project>/` note links UP to its parent and DOWN to its sub-projects. Reports what it will change before writing — dry-run preview is mandatory. Commit prefix `[bot:wiki-heal]`.
