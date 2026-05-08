---
description: "Adversarial vault agent. Takes an idea and argues against it using Nate's own past notes, feedback files, and Claude-Memory. Read-only by default; writes only with --save."
---

Read the `challenge` skill at `skills/challenge/SKILL.md`, then run the workflow. Invocation: `/challenge "idea text"` with optional `--scope <project>`, `--days N`, `--source` (verbose citation mode with file paths + line numbers), and `--save` (write the full report to `03-Concepts/challenges/YYYY-MM-DD-<slug>.md`; without this flag output is terminal-only). The skill resolves the idea into a proposition + anchors, gathers evidence from `03-Concepts/`, `01-Projects/`, `Claude-Memory/`, and classifies each hit as CONTRADICTS / CONSTRAINT / COST_PATTERN / STAKEHOLDER_CONFLICT / DEPENDENCY_BROKEN / SUPPORTS / IRRELEVANT, then renders a ranked report with a GO / PAUSE / STOP / NET-NEW verdict.
