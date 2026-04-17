---
description: "Generate an Obsidian Canvas JSON file that spatializes a concept cluster — useful for seeing a MOC in 2D before linking."
---

Read the `canvas` skill at `skills/canvas/SKILL.md`, then run the workflow. Given a MOC file (or a list of concept wikilinks), the skill writes an Obsidian `.canvas` JSON to `04-Index/canvases/<slug>.canvas` with nodes for each concept and edges for each wikilink. Node positions cluster by tag overlap. The canvas is a view, not a source of truth — regenerating it overwrites layout but preserves the underlying notes. Commit prefix `[bot:wiki-add]`. Follows the writer-role rules in `references/wiki-schema.md` §1.
