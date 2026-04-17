---
name: tether
description: Audit and repair the tethering rules in `05-Projects/` — filename-equals-folder, bidirectional links to MOC/Projects-Index, org-hub tethering (<ORG-A>, GITHUB), sub-project back-links, and unlinked-mention detection. Dry-run by default; atomic per-project transactions on execute. Respects `tether: none` frontmatter opt-outs and never touches cloned repos under `05-Projects/GITHUB/`.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# tether — project-graph audit and repair

Project folders drift. Index files get renamed with stray `-Index` suffixes. New sub-projects don't make it into `Projects-Index.md`. Client work forgets to link back to its org hub. This skill finds those drifts and fixes them — or reports them for review.

## Flags

| Flag | Purpose |
|------|---------|
| `--scope <project>` | Audit exactly one project folder (e.g. `--scope <ORG-B>`). Sub-project paths also accepted (`--scope <ORG-B>/Beard\ Club`). |
| `--all` | Audit every project in `05-Projects/`. |
| `--dry-run` | **Default.** Report violations; do not write. |
| `--execute` | Apply fixes. Atomic per-project — if any step fails for a project, roll that project back. Other projects continue. |

`--dry-run` and `--execute` are mutually exclusive. `--scope` and `--all` are mutually exclusive.

## Rules enforced (from CLAUDE.md)

### Rule 1 — Filename equals folder name

Every project folder has an index note whose filename matches the folder exactly, **with no `-Index` suffix**.

- Correct: `05-Projects/<ORG-B>/<ORG-B>.md`, `05-Projects/GITHUB/GITHUB.md`, `05-Projects/MMA/MMA.md`.
- Wrong: `<ORG-B>-Index.md`, `GITHUB-Index.md`, `MMA-Index.md`.

Wrong filenames break `[[PROJECT]]` wikilink resolution — the wikilink goes stale and the project drifts off the main graph.

Sub-projects follow the same rule: `05-Projects/<ORG-B>/<PROJECT-A>/<PROJECT-A>.md`, `05-Projects/MMA/<PROJECT-B>/<PROJECT-B>.md`.

### Rule 2 — Bidirectional links

Every project index note must link:

- **UP** to `Projects-Index.md` (or `04-MOC/MOC-Projects.md` in the older layout) and to any relevant org hub (`[[<ORG-A>]]`, `[[GITHUB]]`).
- **DOWN** to every sub-project under the folder.

And every sub-project index must link back UP to its parent project. One-way links create islands.

### Rule 3 — Projects-Index membership

`Projects-Index.md` lists every direct child of `05-Projects/`. A new project folder that isn't in Projects-Index is orphaned from the main graph even if its index file is well-formed.

### Rule 4 — Client work tethered to org hub

If a project was built under <ORG-A> (or any org), the project's index has `[[<ORG-A>]]` in its **Related** section. The org hub (`<ORG-A>.md`) lists the project under its **## Repos** or **## Projects** section. Both directions required.

Example: `<ORG-B>/<PROJECT-A>` links to `[[<ORG-B>]]` (its parent) AND `[[<ORG-A>]]` (its org). `<ORG-A>.md` lists the <PROJECT-A> under its projects section.

### Rule 5 — Code projects tethered to GITHUB hub

If a project has a cloned repo under `05-Projects/GITHUB/`, the project's main note links `[[GITHUB]]` in its Related section, and `GITHUB.md` lists the project under its **## Owned By** section.

## Violation categories

The audit classifies problems into four buckets so the run summary is actionable:

1. **Filename mismatches.** An index file is named `FOO-Index.md` instead of `FOO.md`. Also includes wholly missing index files.
2. **Missing Projects-Index entries.** A folder exists under `05-Projects/` but has no entry in `Projects-Index.md`.
3. **Broken bidirectional links.** A project links UP but the target doesn't list it, or a sub-project exists but the parent's DOWN section omits it, or org-hub tethering only goes one way.
4. **Unlinked mentions.** A project name appears as plain text elsewhere in the vault but isn't a `[[wikilink]]`. Each unlinked mention is a free edge left on the table. Surfaced as candidates, not auto-converted (risk of false positives).

## --execute semantics

Atomic per-project transactions. For each project, the skill:

1. Snapshots the project's file list and index note contents.
2. Applies all fixes for that project (rename, edit, append link).
3. If any step errors, restores the snapshot — that project is left exactly as it was found.
4. Moves on to the next project.

A single failing project never halts the full run. The final summary reports per-project success/failure.

### Per-category fixes

- **Filename mismatch:** rename `FOO-Index.md` → `FOO.md`. Then `Grep` the vault for `[[FOO-Index]]` references and update them in the same transaction. If a rename would clobber an existing file, abort that project and flag manually.
- **Missing Projects-Index entry:** insert `[[PROJECT]]` into the appropriate section of `Projects-Index.md` (business / creative / tech / personal — match sibling projects' section).
- **Broken bidirectional link:** append the missing `[[X]]` into the correct section (Related, sub-projects, ## Repos, ## Owned By). Never replace existing content — only append.
- **Unlinked mentions:** **never auto-convert.** Write candidates to `Claude-Memory/tether-candidates-YYYY-MM-DD.md` for the operator to review. Each candidate includes the file path, line, surrounding context, and suggested wikilink.

### Dead-link handling

If the audit encounters a wikilink pointing at a file that no longer exists, wrap it in strikethrough markdown (`~~[[Old Name]]~~`) rather than deleting it. Deletion loses history; strikethrough flags it for manual review.

The skill **never deletes notes**. Renames happen via move (preserves content and history). Edits only append or strike-through.

## Opt-out

A project index with `tether: none` in its frontmatter is skipped entirely. Nothing in the audit applies.

```yaml
---
title: "Experimental Project"
tether: none
---
```

Use sparingly. A `tether: none` project drops off the main graph by design.

## GITHUB subfolder exclusion

`05-Projects/GITHUB/` contains cloned third-party and <ORG-A> repos. **Never touch anything inside `05-Projects/GITHUB/*/`.** These are cloned git repos — their `.md` files are upstream content, not vault notes. The tether skill only looks at `05-Projects/GITHUB/GITHUB.md` itself (the hub note) and `05-Projects/GITHUB/{<ORG-A>-REPOS,MISC-REPOS}/*.md` index notes if they exist. Repo internals are out of scope.

## --dry-run report format

Dry-run output is a grouped violation list:

```
## tether audit — 2026-04-16

### Filename mismatches (1)
- 05-Projects/FOO/FOO-Index.md → should be FOO.md
  → 3 wikilinks reference [[FOO-Index]] and need rewrite

### Missing Projects-Index entries (2)
- <ORG-B>/<PROJECT-A> — not listed in Projects-Index.md
- <ORG-C> — not listed in Projects-Index.md

### Broken bidirectional links (4)
- <ORG-B>/<PROJECT-A> links to [[<ORG-A>]] but <ORG-A>.md does not list it
- MMA/<PROJECT-B> links to [[MMA]] but MMA.md ## Sub-projects omits it
- ...

### Unlinked mention candidates (12)
- 01-Conversations/2026-04-13-misc.md:42 — "<project-a>" (not linked to [[<ORG-B>/<PROJECT-A>]])
- ...

## Summary
17 violations across 8 projects. Run with --execute to apply 5 automatic fixes.
12 unlinked mentions queued to Claude-Memory/tether-candidates-2026-04-16.md for review.
```

## Invariants

- Never delete notes.
- Never touch `05-Projects/GITHUB/<owner>/<repo>/` contents.
- Never auto-convert unlinked mentions (surface only).
- Never bypass `tether: none`.
- Every `--execute` run is atomic per-project.
- Every rename updates all inbound wikilinks in the same transaction.
