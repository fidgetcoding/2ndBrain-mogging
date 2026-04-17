---
name: wiki
description: Add, audit, heal, and find across the 2ndBrain Obsidian vault. Single skill with four branches — ADD ingests sources (URL/file/paste/YouTube/PDF) into the 02-Sources → 03-Concepts → 04-Index pipeline with discuss-before-write; AUDIT is read-only integrity scan; HEAL applies safe repairs on a dry-run branch; FIND is semantic retrieval with wikilink-cited synthesis. Never writes owner:human files, never touches 05-Projects/*/index or 06-Tasks/.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# wiki — add, audit, heal, find

Shared schema: `../references/wiki-schema.md` is the binding source of truth for frontmatter keys, folder roles, wikilink grammar, and the entity/concept/claim data model used below. This file defines the operator-facing behavior; the schema file defines the data.

`wiki` is the single entry point for anything that treats the vault as a knowledge graph rather than a capture bucket. The `save` skill handles conversational capture. `wiki` handles graph-aware work: ingesting sources, auditing graph health, healing known deformations, and searching with citations.

## 1. Entry prompt

When invoked, the skill MUST first print exactly this menu and wait for a number:

```
What do you want to do?
  1. Add    — ingest a source (URL / file / paste / YouTube / PDF) into the wiki
  2. Audit  — scan the vault for contradictions, staleness, orphans, and dead links (read-only)
  3. Heal   — apply safe, reversible repairs to graph deformations on a dry-run branch
  4. Find   — semantic search with wikilink-cited synthesis
  5. Exit
```

Numbers not in `1..5` → re-prompt. Natural-language input ("ingest this URL") → infer the branch and confirm before proceeding.

## 2. Hard rules (all branches)

These are non-negotiable and apply to every branch below:

1. **Never write files with `owner: human` in their frontmatter.** Read the target file's frontmatter BEFORE any Edit/Write. If `owner: human` is present, route around it (log-only, or create a sibling `-wiki.md` file).
2. **Never write to `05-Projects/*/<project-name>.md` or any file directly named as a project index.** Project index files are human-curated (per vault rules in `CLAUDE.md`). `wiki` may LINK into them but never mutate them. Scaffolding new projects is explicitly out of scope for this skill.
3. **Never write anywhere under `06-Tasks/`.** Task state is owned by the Obsidian Tasks plugin and the n8n 3-way sync. `wiki` may READ tasks to resolve wikilink targets but never creates, edits, completes, or deletes a task.
4. **Every branch that writes uses its own git branch.** No direct writes to `main`. Branch names below are the contract.
5. **Every write file includes the frontmatter keys `source_of_truth`, `last_confirmed`, and `owner` per `../references/wiki-schema.md`.**
6. **Branch pollution discipline.** If a branch already exists for today, append to it; do not create `-v2` siblings.

## 3. Branch 1 — ADD

Intake accepts any of: a URL, a local file path, a pasted blob, a YouTube URL, a PDF path.

### 3.1 Pipeline

1. **Download / fetch** if URL.
   - Webpage → `WebFetch` (load via ToolSearch).
   - YouTube → `mcp__yt-dlp__ytdlp_download_transcript` + `mcp__yt-dlp__ytdlp_get_video_metadata`.
   - PDF → `Read` with `pages:` if >10 pages, else single read.
   - Pasted blob → use as-is.
2. **Save to `02-Sources/`** with filename `SRC-<YYYY-MM-DD>-<slug>.md`. Frontmatter:
   ```yaml
   ---
   title: "<original title>"
   type: source
   source_url: "<canonical URL or 'paste'>"
   source_kind: web | youtube | pdf | paste | file
   captured_at: 2026-04-16
   owner: wiki
   last_confirmed: 2026-04-16
   tags: []
   concepts: []      # filled after extraction
   entities: []      # filled after extraction
   ---
   ```
3. **Extract**:
   - Entities (named things: people, companies, products). Use regex + he<person-i>stics for proper nouns; cross-check against `Claude-Memory/aliases.yaml`.
   - Concepts (ideas, techniques, frameworks). Maintain an internal scorer: multi-word noun phrases that repeat ≥ 2× inside the source.
   - Claims (testable assertions). Each claim = `{text, confidence, supports_or_refutes: <existing_claim_id?>}`.
4. **Cross-reference `03-Concepts/`.** `Glob` for existing concept pages; match by frontmatter `aliases:` list before filename slug. This is CRITICAL — re-creating a slightly-differently-named page is the #1 graph-pollution failure.
5. **DISCUSS BEFORE WRITE.** This is the defining ADD-branch rule. Before any preview table, print:
   ```
   I read this source. Here are the 3–5 takeaways I'd encode:
     1. <takeaway 1, one sentence, neutral framing>
     2. <takeaway 2>
     3. <takeaway 3>
     4. <takeaway 4, optional>
     5. <takeaway 5, optional>

   Anything you want me to emphasize, reframe, or skip? (type notes, or `ok` to proceed)
   ```
   The skill then WAITS. This is not optional. If the user says "skip 3", that takeaway does NOT become a concept page update. If the user says "emphasize 2", that takeaway's concept page gets a prominent lede block instead of a b<person-i>ed bullet.
6. **Dry-run preview table.** After the user types `ok`, print the standard preview:
   ```
   ┌────────────────────────────────────────────┬──────────────────────────────────────────────────────┬─────────┐
   │ Write                                      │ Path                                                 │ Op      │
   ├────────────────────────────────────────────┼──────────────────────────────────────────────────────┼─────────┤
   │ Source page                                │ 02-Sources/SRC-2026-04-16-<person-e>-morgen-mcp.md   │ create  │
   │ Concept: "first-party MCP"                 │ 03-Concepts/first-party-mcp.md                       │ update  │
   │ Concept: "rate limit 300/15min"            │ 03-Concepts/morgen-rate-limit.md                     │ create  │
   │ Entity: "<PERSON-E>"                       │ 03-Concepts/<person-e>.md                            │ create  │
   │ Index update                               │ 04-Index/Index.md                                    │ append  │
   │ Log entry                                  │ 04-Index/log.md                                      │ append  │
   └────────────────────────────────────────────┴──────────────────────────────────────────────────────┴─────────┘

   Git branch: wiki-add/2026-04-16-<person-e>-morgen-mcp
   Expected touch count: 10–15 pages
   Proceed? (y/n)
   ```
7. **On `y`:** execute writes. Commit prefix: none (this branch lives outside the `obsidian-tasks-sync` repo).

### 3.2 Source page shape (factual-only)

Source pages (`02-Sources/`) are strictly evidence. No interpretation, no opinion, no synthesis. The shape is fixed:

```markdown
---
<frontmatter as above>
---

# <Title>

## Summary
<2–5 sentences, strictly what the source says. No Nathan-voice. No editorial.>

## Key Claims
- Claim 1 (with in-source citation if available).
- Claim 2.
- Claim 3.

## Entities Mentioned
- [[<PERSON-E>]] — role in source, e.g., "Morgen engineering, 2026-04-15 email."
- [[Morgen MCP]]
- [[n8n W1]]

## Concepts Covered
- [[first-party MCP]]
- [[morgen-rate-limit]]

## Raw
<optional: bullet dump of other notable quotes or data points>
```

Interpretation, synthesis, and Nathan-voice live in concept pages (`03-Concepts/`) and permanent notes (`03-Permanent/`). Source pages are the audit trail.

### 3.3 Concept page updates (prefer update)

When a concept already exists, UPDATE instead of CREATE. "Update" means:
- Append a line to the concept's `Evidence` section linking back to the source: `- [[SRC-2026-04-16-<person-e>-morgen-mcp]] — confirms rate limit raised 100→300/15min as of 2026-04-15.`
- Update `last_confirmed:` in frontmatter to today.
- If the new source CONTRADICTS an existing claim, add a `## Contradictions` section rather than silently overwriting. Human reviews contradictions; skill never adjudicates.

Only create a new concept page if `Glob` + alias resolution truly returns zero matches.

### 3.4 Index + log

- `04-Index/Index.md` gets one new line per new concept or entity page, sorted into its topical section.
- `04-Index/log.md` gets an append-only entry:
  ```
  2026-04-16 ADD source=SRC-2026-04-16-<person-e>-morgen-mcp created=2 updated=3 branch=wiki-add/2026-04-16-<person-e>-morgen-mcp
  ```

Expected touch count per ADD run: **10–15 pages** (1 source + 3–8 concepts + 2–5 entities + index + log). If a run is projecting > 20 touches, pause and ask the user to confirm — large writes are usually a symptom of missed alias matches.

## 4. Branch 2 — AUDIT (read-only)

AUDIT never writes except to a timestamped report. It scans:

| Check                       | Detection                                                                                              |
|-----------------------------|--------------------------------------------------------------------------------------------------------|
| Contradictions              | Concept pages containing `## Contradictions` sections, or two pages making opposite claims about the same entity. |
| Stale claims                | Any page whose `last_confirmed:` is older than 180 days.                                               |
| Orphan pages                | Pages in `02-Sources/` or `03-Concepts/` with zero inbound wikilinks from elsewhere in the vault.      |
| Missing concept pages       | Entities mentioned ≥ 3 times across `02-Sources/` with no page in `03-Concepts/`.                      |
| Dead wikilinks              | `[[foo]]` where no file `foo.md` (or alias-resolved target) exists.                                    |
| Missing cross-refs          | Concept A references Concept B, but Concept B has no reverse mention of A.                             |
| Index consistency           | `04-Index/Index.md` lists a page that no longer exists, or a page that exists but isn't in the index.  |
| Data gaps                   | Pages with frontmatter fields missing per `../references/wiki-schema.md` (e.g., `source_of_truth` empty). |

### 4.1 Mechanics

Use `Glob` to enumerate files. Use `Grep` for wikilink/frontmatter extraction (multiline where needed for frontmatter). Do not instantiate an LLM call for any of the above — the detectors are deterministic regex + set-arithmetic on the link graph.

Build two in-memory sets:
- `pages = { basename → path, frontmatter, wikilinks_out }` for everything under `02-Sources/`, `03-Concepts/`, `03-Permanent/`, `04-Index/`, `04-MOC/`.
- `inbound = { basename → [paths that link to it] }` via inversion.

### 4.2 Output

Write the report to `04-Index/audit-YYYY-MM-DD.md`. Shape:

```markdown
---
title: "Wiki audit 2026-04-16"
type: audit
generated_at: 2026-04-16
owner: wiki
---

# Audit 2026-04-16

## Executive summary
- Pages scanned: 412
- Issues: 23 (contradictions: 1, stale: 12, orphan: 4, missing-concept: 3, dead-link: 2, missing-crossref: 1, index-drift: 0, data-gap: 0)
- Suggested action: run `/wiki` → 3 (Heal) to clear 19 of 23 mechanically; 4 require human review (listed below).

## Contradictions (1) — HUMAN REVIEW REQUIRED
- [[morgen-rate-limit]] states "100/15min" in one block and "300/15min" in another. Source conflict: [[SRC-2026-03-20-morgen-launch]] vs [[SRC-2026-04-15-<person-e>-email]].

## Stale (12) — safe to auto-mark needs_review
<bulleted list with last_confirmed date>

## Orphans (4)
<bulleted list>

...
```

AUDIT is idempotent — running it twice on the same day updates (overwrites) the same audit file rather than creating siblings.

## 5. Branch 3 — HEAL (dry-run default)

HEAL is the only branch that mutates the graph outside ADD. It operates in dry-run mode by default: it computes a plan, writes it to a preview file, creates a git branch `wiki-heal/YYYY-MM-DD`, makes the edits on that branch, and leaves the human to review with `git diff main` before merging.

### 5.1 Allowed repairs

| Action                                             | Trigger                                                                    | Risk  |
|----------------------------------------------------|----------------------------------------------------------------------------|-------|
| Create stub concept page                           | Entity mentioned ≥ 3× with no page                                         | Low   |
| Wrap bare concept name in `[[wikilinks]]`          | Concept name appears unlinked in a page where the concept page exists      | Low   |
| Mark page with `needs_review: true` in frontmatter | `last_confirmed:` older than 180 days                                      | None  |
| Strike through dead wikilink text                  | `[[foo]]` where foo has no target                                          | Low   |
| HTML-comment annotation on dead links              | Add `<!-- wiki: unresolved 2026-04-16 -->` adjacent to the struck link     | None  |

### 5.2 Disallowed repairs (require human)

- Resolving contradictions (HEAL never picks a side).
- Merging concept pages (too easy to lose evidence links).
- Renaming pages (breaks every wikilink pointing at them; must be a deliberate human action).
- Changing `owner: human` frontmatter.
- Touching `05-Projects/*/<index>.md` or `06-Tasks/**`.

### 5.3 Stub pages

A stub created by HEAL has the shape:

```markdown
---
title: "<Name>"
type: concept
created_by: wiki-heal
created_at: 2026-04-16
owner: wiki
source_of_truth: pending
last_confirmed: 2026-04-16
needs_review: true
aliases: []
---

# <Name>

> Stub created by `/wiki heal` because <Name> was mentioned in N sources with no dedicated page. Expand with evidence and remove `needs_review: true` once real content is present.

## Mentioned In
- [[source-1]]
- [[source-2]]
```

The stub is intentionally minimal. Its only job is to resolve the dangling link and hold breadcrumbs until a human fills it in — OR until the next ADD run enriches it through the normal update path.

### 5.4 Dead-link handling

`[[foo]]` with no target becomes:

```
~~[[foo]]~~ <!-- wiki: unresolved 2026-04-16 -->
```

Strikethrough preserves reader intent ("there was supposed to be a link here") while flagging the deformation. The HTML comment is machine-readable so a future HEAL run can revisit once `foo.md` exists.

### 5.5 Branch lifecycle

1. Create branch: `git checkout -b wiki-heal/2026-04-16` (if vault is a git repo; else skip and operate in-place with a WARN).
2. Apply all HEAL edits.
3. Write `04-Index/heal-plan-2026-04-16.md` summarizing every change.
4. Commit each category as a separate commit for reviewability:
   - `wiki-heal: stub pages for N missing concepts`
   - `wiki-heal: wrap unlinked concept names`
   - `wiki-heal: mark stale pages needs_review`
   - `wiki-heal: strike dead links`
5. Print:
   ```
   Heal branch wiki-heal/2026-04-16 pushed. 23 issues repaired. Review with:
     git diff main..wiki-heal/2026-04-16
   Merge when ready. DO NOT run /wiki heal again before merging — it will rebase off the same base.
   ```

## 6. Branch 4 — FIND

FIND is semantic retrieval with transparent reasoning.

### 6.1 Steps

1. Ask: "What are you looking for?"
2. **Semantic search.** Compute embedding of the query. Compare against a precomputed embedding index at `Claude-Memory/wiki-embeddings.jsonl` (one line per page). If the index is missing or older than 7 days, offer to rebuild it first.
3. **Read relevant pages** (top K=5 by cosine). Show which pages are being read so the user can flag misses early.
4. **Synthesize** an answer that:
   - Cites every claim with an inline `[[wikilink]]` to its source or concept page.
   - Lists the pages read at the top under "Sources" so the user can verify.
   - Separates "what the wiki says" from "what I think" — the latter only if the user asked for an opinion.
5. **Offer to save.** Print:
   ```
   Save this synthesis as a permanent note? (y/n)
   Default path: 03-Permanent/synth-<slug>-2026-04-16.md
   ```
   If `y`, hand off to `/save` branch 3 (dictated note, type=permanent) with the synthesis pre-filled.

### 6.2 No hallucinated citations

A critical FIND rule: the skill MUST NOT emit a `[[wikilink]]` to a page that isn't in the "Sources" list at the top. If the synthesis needs to reference a page that wasn't read, either:
- Read it and add it to Sources, or
- State the claim without a citation and flag it as `[unsourced]`.

## 7. Failure modes

| Failure                                                | Detection                                | Recovery                                                                 |
|--------------------------------------------------------|------------------------------------------|--------------------------------------------------------------------------|
| Source URL returns 404 / paywalled                     | HTTP status                              | Record failure in `04-Index/log.md`, save captured paste/prompt text only, tag `source_status: unreachable`. |
| Source is a YouTube URL with no transcript available   | yt-dlp returns empty                     | Offer to run whisper-mcp on the audio as fallback; require explicit `y`. |
| Target concept page has `owner: human`                 | Frontmatter check before Edit            | Skip the Edit, write a sibling `-wiki.md` file, and link it from Evidence. |
| `aliases.yaml` missing or malformed                    | YAML parse                                | Abort with clear error; suggest running ADD on a high-level alias source.|
| ADD proposes > 20 touches                              | Preview count                            | Pause, ask user to confirm — likely a missed alias match.                 |
| FIND embedding index stale (> 7d) or missing           | Mtime check / file absent                | Offer to rebuild; require explicit `y`; skip otherwise with WARN.        |
| HEAL branch has unmerged predecessor                   | `git branch --list wiki-heal/*`          | Refuse to create a new HEAL branch until the old one is merged or deleted. |
| AUDIT on a vault > 10k pages                           | Page count                                | Warn about runtime; offer to scope to `03-Concepts/` only by default.    |
| Source page write collides with an existing SRC file   | `Glob` match on slug                      | Append `-v2`, `-v3`, etc., and record the collision in log.              |
| Dead link has a HEAL comment from > 30 days ago        | Regex on HTML comments                   | Escalate in next AUDIT as "long-unresolved"; do NOT auto-delete the link.|

## 8. Non-goals (explicitly out of scope)

- `wiki` does not scaffold new projects in `05-Projects/`. Use the documented human workflow in `CLAUDE.md` (`### Project Index Note Rules`).
- `wiki` does not manage tasks. Tasks live in `06-Tasks/` + Obsidian Tasks plugin + the n8n 3-way sync.
- `wiki` does not deploy anything, run migrations, or modify `.env*`, `.claude/`, or `node_modules/`.
- `wiki` does not delete files. Even in HEAL, deletion requires a human.
- `wiki` does not call external paid services d<person-i>ng AUDIT — AUDIT is pure regex + graph arithmetic.

## 9. Cross-skill handoff

`wiki` and `save` are peers, not hierarchy. They hand off at two seams:

- **FIND → save.** FIND can propose saving a synthesis; the actual write is delegated to `/save` branch 3.
- **ADD "discuss before write" residue → save.** If d<person-i>ng DISCUSS the user says "this is really a fleeting thought, not a source," the ADD run aborts cleanly and suggests `/save` branch 3.

Both skills read the same `../references/wiki-schema.md` and the same `Claude-Memory/aliases.yaml`. If those two files ever drift, fix the schema first — it's the source of truth, and both skills are downstream.

Reference: `../references/wiki-schema.md` is the binding definition for every frontmatter key, folder role, and linking grammar token used above. Read it before any write.
