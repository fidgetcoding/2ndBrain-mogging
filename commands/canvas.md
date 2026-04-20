---
description: "Generate and maintain Obsidian Canvas files from vault queries — adds images, text, PDFs, pinned notes, and labeled zones with strict JSON Canvas 1.0 validation."
---

Read the `canvas` skill at `skills/canvas/SKILL.md`, then run the workflow. Subcommands: `new <name>` creates an empty `04-Index/canvases/<slug>.canvas`; `add image|text|pdf|note` appends nodes with deterministic `{type}-{slug}-{unix-ts}` IDs; `zone <name> [color]` creates a labeled group container; `list` enumerates every `.canvas` in the vault with node/edge counts; bare `/canvas` prints a status report. The central `04-Index/Map.canvas` uses a Fibonacci-spiral layout and `/canvas map-rebuild` is idempotent — existing node IDs and positions are preserved. The skill is a view layer — it NEVER mutates source notes, validates JSON Canvas 1.0 before every write, and rejects path traversal.
