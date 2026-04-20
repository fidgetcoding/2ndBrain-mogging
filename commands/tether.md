---
description: "Repair orphaned notes and bidirectionally link projects, sub-projects, MOCs, and hubs — closes broken graph bridges."
---

Read the `tether` skill at `skills/tether/SKILL.md`, then run the workflow. Flags: `--scope <project>` or `--all` (mutually exclusive), `--dry-run` (default, reports only) or `--execute` (atomic per-project fixes). The skill enforces the CLAUDE.md tethering rules: filename-equals-folder (no `-Index` suffix), bidirectional UP/DOWN links, `04-Index/Projects-Index.md` membership, client-work-to-org-hub tethering (`[[<ORG-A>]]`), and code-project-to-`[[GITHUB]]` tethering. Violations classify into filename mismatches, missing Projects-Index entries, broken bidirectional links, and unlinked mentions (surfaced to `Claude-Memory/tether-candidates-YYYY-MM-DD.md`, never auto-converted). Respects `tether: none` frontmatter opt-outs. Never touches anything inside `05-Projects/GITHUB/<owner>/<repo>/` or deletes notes.
