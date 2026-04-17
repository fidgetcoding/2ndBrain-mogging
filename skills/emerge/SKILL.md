---
name: emerge
description: Pattern-miner across recent vault activity. Scans files modified in the last N days, extracts signals, clusters them semantically, and names each cluster as a candidate concept — short, concrete, anti-jargon. Powers weekly vault review. Use when the user says /emerge, asks "what themes have been showing up lately", wants a weekly digest, or is looking for latent patterns they haven't named yet.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /emerge — Pattern Mining Across Recent Activity

The vault gets denser every day. Some of that density is signal — a concept showing up independently across three projects in two weeks. Most is noise. `/emerge` separates them.

## When to Invoke

- User runs `/emerge` manually, usually at end of week or start of a review.
- Scheduled weekly agent (Sunday 9pm EST) runs `/emerge --days 7 --audit` non-interactively and writes the report to `01-Conversations/VAULT/reports/emerge-YYYY-WW.md`.
- After a burst of activity (e.g. the operator just closed a Lava deliverable sprint and wants to see what emerged).

Do NOT auto-run `/emerge` inside another skill's pipeline except the scheduled agent. It's expensive and slow.

## Invocation

```
/emerge
/emerge --days 14
/emerge --days 7 --scope 07-Projects/<ORG-C> --min-cluster 2
/emerge --days 7 --audit
/emerge --promote cluster-3
```

## Flags

| Flag | Default | Behavior |
|---|---|---|
| `--days N` | 30 | Only consider files modified in the last N days. |
| `--scope <path>` | whole vault | Restrict to a single folder (e.g. `07-Projects/<ORG-E>`). |
| `--min-cluster N` | 3 | Minimum file count for a cluster to be reported. Below this, treated as noise. |
| `--audit` | off | Non-interactive mode for the scheduled weekly agent. Writes directly to the reports folder, no prompts. |
| `--promote <pattern-id>` | — | Skip mining. Take a previously-identified cluster and promote it to a full `03-Concepts/<slug>.md` note. |

## Pipeline

### 1. Collect

Glob all vault files modified in the time window. Exclude `06-Assets/`, `node_modules/`, `.obsidian/`, `.git/`, `.claude/`, `.agents/`. **Cap at 500 files.** If over cap, sample by:
- Recency (newer = higher weight)
- Project diversity (one `07-Projects/<ORG-C>/content/` note ≠ ten of them — cap per-folder contribution)

### 2. Extract signals

Per file, extract:
- **Entities**: capitalized multi-word strings, `[[wikilinks]]`, frontmatter `related:` list.
- **Concepts**: noun phrases appearing ≥2 times or in H1/H2 headings.
- **Tags**: frontmatter tags + inline `#tag` mentions.
- **Actions**: verbs attached to project names (e.g. "shipped Morgen", "killed <PROJECT-A> Report").
- **Sentiment markers**: the operator's loaded language — "panic", "theater", "clean", "mogging", "janky", "ship-and-fix-forward", all caps emphasis.

Signals are stored as `(file_path, signal_type, signal_value, weight)` tuples.

### 3. Cluster

Semantically cluster the signals. Preferred: HDBSCAN on sentence-embedded signal strings (handles varying cluster sizes). Fallback if embeddings unavailable: k-means with k = sqrt(total_signals) / 2, followed by silhouette-score-based merge of tight clusters.

Each cluster must have:
- `file_count` ≥ `--min-cluster`
- At least 2 distinct projects OR at least 2 distinct file types (literature / permanent / fleeting / project-note)

Single-project single-type clusters = project noise, drop them.

### 4. Name each cluster

For every surviving cluster, generate 2-3 candidate names. **Name discipline**:
- **Short**: 2-5 words.
- **Concrete**: prefer nouns over gerunds, compounds over abstractions.
- **Anti-jargon**: do not use "synergy", "orchestration", "framework", "paradigm", "leverage", "ecosystem", "stack" unless the cluster is literally about a software stack.
- **Match the operator's naming DNA**: reference `feedback_cli_maxxing_folder`, `project_tribecoding`, `project_fidgetcoding_rename` in Claude-Memory. Names are playful-terse ("tribecoding", "mogging", "task-maxxing"), not PMish ("collaborative coding ecosystem").
- **No emoji**. No brackets. No trailing ellipses.

Pick the strongest candidate as primary, list the other two as alternates.

### 5. Score and rank

```
score = source_count × recency_factor × cross_project_bonus × (1 - noise_penalty)
```

- `source_count`: file count in cluster.
- `recency_factor`: weighted average of file mtimes (newer = higher).
- `cross_project_bonus`: 1.0 single-project, 1.5 two-project, 2.0 three+ project — cross-project emergence is the strongest signal of a real pattern.
- `noise_penalty`: penalty for clusters dominated by low-signal file types (inbox, fleeting). Reduces score 0-0.4.

Report top 10 clusters by score.

### 6. Render

```
# Emerge: Last N Days

Run ID: emerge-YYYY-WW-<short-hash>
Files scanned: X (capped at Y)
Clusters surviving: Z

---

## Cluster 1: <primary name>
Alternates: <alt1>, <alt2>
Score: 8.4  |  Files: 7  |  Projects: 3 (<ORG-E>, <ORG-A>, <ORG-C>)
Recency: median 4 days ago

**Gist**: one-paragraph synthesis of what's emerging.

**Sources**:
- `file/path.md` (2026-04-14) — one-line why it belongs
- ...

**Existing overlap**: `[[existing-concept]]` (85% match) — propose merge not new note.

**Promote?** `/emerge --promote cluster-1`

---

## Cluster 2: ...
```

### 7. Cross-reference existing concepts

Before emitting a cluster, check `03-Concepts/` and `03-Permanent/` for overlapping notes. If a proposed pattern overlaps ≥70% with an existing concept:
- Do NOT propose a new note.
- Instead, label the cluster `[MERGE-CANDIDATE]` and suggest updating the existing note with the new sources.

### 8. --promote behavior

`/emerge --promote cluster-3` from the last run:
- Read cached cluster data from `01-Conversations/VAULT/reports/emerge-YYYY-WW.md`.
- Create `03-Concepts/<slug>.md` with frontmatter:
  ```yaml
  ---
  title: "<primary name>"
  date: 2026-04-16
  type: concept
  emerged_from: emerge-YYYY-WW-<hash>
  cluster_id: cluster-3
  sources:
    - [[source-note-1]]
    - [[source-note-2]]
    ...
  tags: []
  ---
  ```
- Body = gist paragraph + "Sources" section (wikilinks) + placeholder "Open Questions" section.
- Add `[[<slug>]]` to relevant MOC (detect via cluster's dominant project or tag).
- Add backlinks from source notes? No — let the graph find them via the `sources:` frontmatter and wikilinks in the body.

## Scheduled Agent Integration

Weekly agent config (managed in `~/.claude/hooks/` not here):
- Trigger: Sunday 9pm EST
- Command: `/emerge --days 7 --audit`
- Output: `01-Conversations/VAULT/reports/emerge-YYYY-WW.md` (ISO week number)
- Side effect: appends one-line summary to `01-Conversations/VAULT/reports/emerge-log.md` (run ID, cluster count, top cluster name).

The `--audit` flag means:
- No interactive prompts.
- Skip clusters below `--min-cluster` silently.
- Never promote automatically — leave that to the operator.
- If no clusters survive, still write the report (noting "no emergent patterns this week") — silence is also data.

## Edge Cases

- **Sprint file explosion**: per-folder cap at step 1 keeps sprint clusters from drowning cross-project signals.
- **Sync noise**: skip frontmatter-only modifications (`updated:` timestamp bumps). Use content hash, not mtime alone.
- **Over-clustering**: if >15 clusters emerge, tighten `--min-cluster` to 4 and re-run.
- **Claude-Memory absent**: works without it but loses naming-discipline signal. Log warning.
- **`--promote` on missing cluster ID**: fuzzy-match against recent runs, confirm before creating.

## Soft Calls

May invoke `/connect` read-only to check if a cluster bridges otherwise-disconnected regions (+cross_project_bonus). May invoke `/challenge` on a `--promote` candidate to stress-test before note creation.
