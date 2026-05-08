---
name: aliases
description: Bootstrap and maintain `Claude-Memory/aliases.yaml` — the canonical entity→project disambiguation file used by `/backfill`, `/save`, and `/tether` to route mentions to the right project folder. Handles people (<PERSON-C> vs <PERSON-B>, <PERSON-A>, <PERSON-D>, <PERSON-H>, <PERSON-E>, <PERSON-I>, <PERSON-F>), concepts ("tribecoding", "<PROJECT-C>", "<PROJECT-A>"), organizations, and alternate spellings. Never overwrites canonical without review.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# aliases — entity disambiguation registry

> All example names in this file are placeholders. The real-name mapping is private. See docs/placeholder-names.md.

Downstream skills can only route transcripts to the correct project if they know that "<PERSON-C>" means <ORG-B>/<PROJECT-A> and "<PERSON-B>" is a different person entirely. This skill owns the registry that makes that call.

## Location

```
Claude-Memory/aliases.yaml
```

Single-file source of truth. Every other skill (`/backfill`, `/save`, `/tether`, `/wiki`, `/connect`) reads from it; only this skill writes to it.

## Flags

| Flag | Purpose |
|------|---------|
| `--bootstrap` | First-time population. Scans the vault, memory files, task files, and frontmatter to produce an initial `aliases.yaml`. Will NOT overwrite an existing canonical file — emits to `aliases-pending.md` instead. |
| `--suggest` | Scan recent vault changes (last 14 days of mtime) for new proper nouns and undeclared entities. Emit proposals to `Claude-Memory/aliases-pending.md`. |
| `--validate` | Static-check the current `aliases.yaml` for conflicts, duplicates, cycles, orphans, and broken project paths. Read-only. |
| `--edit` | Interactive edit session. Prompts per-section and diffs changes before writing. |
| `--accept` | Merge `aliases-pending.md` into `aliases.yaml`. Requires `aliases-pending.md` to exist. Writes a backup to `aliases.yaml.bak` first. |

## Schema

```yaml
# Claude-Memory/aliases.yaml
version: 1
updated: 2026-04-16

projects:
  <ORG-B>:
    path: 01-Projects/<ORG-B>
    aliases: ["<ORG-B>", "<ORG-B>"]
  <ORG-B>/<PROJECT-A>:
    path: 01-Projects/<ORG-B>/<PROJECT-A>
    aliases: ["<project-a-lower>", "<PROJECT-A>", "<project-a-colloquial>"]
  MMA/<PROJECT-B>:
    path: 01-Projects/MMA/<PROJECT-B>
    aliases: ["<project-b-short>", "<project-b-lower>", "<PROJECT-C>", "<project-c-amp>", "<PERSON-H>'s funnel"]
  # ...one entry per 01-Projects folder

people:
  person_a_<ORG-B>:
    canonical: <PERSON-C>
    project: <ORG-B>/<PROJECT-A>
    aliases: ["<PERSON-C>"]
    disambig_note: "<PERSON-C> (with one L) — <ORG-B> <PROJECT-A> collaborator. NOT <PERSON-B>."
    public_safe: true
  person_b_unknown:
    canonical: <PERSON-B>
    project: null
    aliases: ["<PERSON-B>"]
    disambig_note: "<PERSON-B> (with two L's) — distinct from <PERSON-C>. Public_safe=false (see feedback_no_public_placeholders)."
    public_safe: false
  person_a_placeholder:
    canonical: <PERSON-A>
    project: MISC-CLAUDE
    aliases: ["<PERSON-A>"]
    public_safe: false
  person_d_placeholder:
    canonical: <PERSON-D>
    project: <ORG-B>
    aliases: ["<PERSON-D>"]
    public_safe: true
  person_h_placeholder:
    canonical: <PERSON-H>
    project: MMA/<PROJECT-B>
    aliases: ["<PERSON-H>", "<person-h-short>"]
    public_safe: true
  person_e_placeholder:
    canonical: <PERSON-E>
    project: MORGEN-MCP
    aliases: ["<PERSON-E>", "JM@morgen"]
    public_safe: true
  person_i_placeholder:
    canonical: <PERSON-I>
    project: <ORG-C>/content
    aliases: ["<PERSON-I>"]
    disambig_note: "<PERSON-I> — NFX AI Bigger Than SaaS article author. Tied to SaaS Death Video idea."
    public_safe: true
  person_f_placeholder:
    canonical: <PERSON-F>
    project: <ORG-D>
    aliases: ["<PERSON-F>"]
    public_safe: true

concepts:
  concept_tribecoding:
    canonical: Tribecoding
    project: Terminal-Reimagined
    aliases: ["tribecoding", "tribe coding", "collab coding"]
  concept_project_c:
    canonical: <PROJECT-C>
    project: MMA/<PROJECT-B>
    aliases: ["<project-c-lower>", "<project-c-amp>", "c&w funnel"]
  concept_project_a:
    canonical: <PROJECT-A>
    project: <ORG-B>/<PROJECT-A>
    aliases: ["<project-a-lower>", "<project-a-colloquial>"]
  concept_fidgetcoding:
    canonical: <ORG-C>
    project: <ORG-C>
    aliases: ["fidget coding", "fidgetcoding", "coding for fun"]

orgs:
  org_<ORG-A>:
    canonical: <ORG-A>
    aliases: ["<ORG-A>", "<ORG-A>", "<ORG-A>", "<ORG-A> HQ"]
  org_lava_foundation:
    canonical: <ORG-E>
    aliases: ["Lava", "Lava Foundation", "lava net", "LavaNet"]
  org_morgen:
    canonical: MORGEN-MCP
    aliases: ["Morgen", "morgen.so", "Morgen Labs"]

# Alternate spellings that don't belong to a specific entity but need
# to be normalized before matching (e.g. autocorrect drift, typos).
aliases:
  "the operator": user_nathan
  "operator@example.com": user_nathan
```

## <PERSON-C> vs <PERSON-B> — canonical disambiguation

Two distinct people. Never collapse.

- **<PERSON-C>** (one L) → `person_a_<ORG-B>` → <ORG-B>/<PROJECT-A>. the operator's collaborator on the <PROJECT-A> pitch.
- **<PERSON-B>** (two L's) → `person_b_unknown` → project unknown (TBD).

**Rules:**

1. **Case-sensitive when spelling distinguishes.** "<PERSON-C>" and "<PERSON-B>" are two different lookup keys. Do not lowercase before matching.
2. **Context scoring as tiebreaker.** If a transcript mentions "<PERSON-C>" near <ORG-B> / <PROJECT-A> terms, confidence is high. If "<PERSON-C>" appears cold with no project context and the surrounding conversation is about a non-<ORG-B> area, mark low confidence and surface to pending.
3. **Prompt on genuine ambiguity.** If the transcript actually says something like "<PERSON-C> or <PERSON-B>" or the spelling is illegible (OCR, autocorrect drift), write both candidates into `aliases-pending.md` with the surrounding quote and let the operator resolve.
4. **Honor `public_safe: false`.** <PERSON-A> and <PERSON-B> both carry this flag per `feedback_no_public_placeholders.md`. Any skill generating public artifacts (READMEs, release notes, public repo commits) must read this flag and substitute a placeholder. Private vault notes are fine.

## Bootstrap sources

`--bootstrap` populates `aliases.yaml` by pulling from:

1. **Folder scan of `01-Projects/`.** Every direct child folder becomes an entry in `projects:`. Sub-project folders (`<ORG-B>/<PROJECT-A>`, `MMA/<PROJECT-B>`) get their own entries.
2. **Memory file grep.** Walk `~/.claude/projects/**/memory/MEMORY.md` and the project-specific memory files referenced there. Extract canonical IDs (`project_*`, `person_*`, `user_*`, `concept_*`).
3. **Proper-noun scan of the vault.** Run a capitalized-word frequency analysis across all `.md` files. Candidates with ≥ 3 mentions get surfaced as person/concept proposals.
4. **Task file `@name` mentions.** `Grep` `05-Tasks/**` for `@Name` patterns — Obsidian Tasks assignee mentions.
5. **Frontmatter `related:` arrays.** Every `related: [[X]]` is evidence that `X` is a canonical thing. Harvest the referenced targets.

Bootstrap never writes directly to `aliases.yaml` if one exists. It always writes to `Claude-Memory/aliases-pending.md` for review.

## --suggest behavior

Scans vault changes over the last 14 days. For each new proper noun or undeclared entity:

- Proposes an entry with best-guess `project:` from path context.
- Shows a 1-line quote from the first occurrence.
- Flags potential collisions with existing aliases.

Output goes to `aliases-pending.md`. Never overwrites canonical.

## --validate checks

Run as a read-only audit. Each check that fails is reported with a line reference:

1. **No duplicate keys.** Every top-level key under `people:`, `concepts:`, `orgs:`, `projects:` is unique.
2. **Every `project:` path exists** in `01-Projects/`. Dangling paths are errors.
3. **Disambig pairs both have `disambig_note`.** If two entries share a canonical-ish name (<PERSON-C>/<PERSON-B>), both must explain the distinction.
4. **No cyclic aliases.** An alias cannot point to another alias that points back (or forward-chains back).
5. **Orphan check.** Every folder under `01-Projects/` must appear under `projects:`. A folder with no `projects:` entry is an orphan and gets surfaced for `--bootstrap` to fill.

`--validate` exits non-zero if any check fails. Use in CI-style workflows before `/backfill --apply`.

## --accept merge semantics

- Backup: copy `aliases.yaml` → `aliases.yaml.bak` (timestamped) before any merge.
- Three-way merge: `aliases.yaml` (base) + `aliases-pending.md` (new) → updated `aliases.yaml`.
- Conflict rule: if a key exists in both, the pending entry is appended as a comment block (never silently overwrites).
- After merge, clear `aliases-pending.md` but retain a dated copy at `Claude-Memory/aliases-pending-YYYY-MM-DD.md` for audit.

## Invariants

- Never touch `aliases.yaml` outside `--edit` or `--accept`.
- Never promote a pending suggestion to canonical without explicit `--accept`.
- Never strip a `public_safe: false` flag.
- Always run `--validate` after `--accept` and bail if it fails (restore from `.bak`).
