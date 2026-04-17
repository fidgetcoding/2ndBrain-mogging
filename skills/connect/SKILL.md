---
name: connect
description: Bridge two unrelated notes by finding semantic overlap, shared structural patterns, and candidate intermediate bridge notes. Read-only — never writes, never saves. Outputs 3-5 concrete connections typed as structural analogy, transfer opportunity, or collision idea. Use when the user says /connect with two wikilinks, wants to see how two ideas relate, or is hunting for creative cross-pollination between projects.
allowed-tools: Read, Grep, Glob
---

# /connect — Bridge Two Notes

Any two notes share *some* connection if you squint. `/connect` surfaces only the 3-5 strong enough to be actionable. Read-only. Always.

## When to Invoke

- User runs `/connect [[note-A]] [[note-B]]`.
- User asks "how do these two relate" / "what's the bridge between X and Y".
- Soft-invoked by `/emerge` (to check if a cluster bridges disconnected regions) and `/challenge` (to find counter-argument notes anchors would miss).

Do NOT invoke for trivially-related pairs (same folder, overlapping tags) — that's a cluster. Suggest `/emerge` instead.

## Invocation

```
/connect [[<person-h>-funnel]] [[content-ideas]]
/connect [[morgen-mcp]] [[POETRY]] --depth deep
/connect [[<ORG-E>]] [[fidgetcoding]] --via [[brand-ideation]]
```

## Flags

| Flag | Default | Behavior |
|---|---|---|
| `--via <intermediate>` | none | Force the bridge to route through a specific intermediate note. Useful when the operator has a hypothesis and wants verification. |
| `--depth surface\|deep` | `surface` | `surface` = direct adjacency only (1-2 hops). `deep` = up to 3-hop paths through shared tags, entities, stakeholders. |

## Hard Rule: NEVER WRITES

- No `--save`.
- No `Write` tool access.
- No `Edit` tool access.
- No file creation under any circumstance.

Output is terminal-only. If the operator wants to persist a connection, he copy-pastes manually. This is by design — most connections are junk, and writing them would pollute the vault. The friction of manual copy is the filter.

## Pipeline

### 1. Resolve both targets

Parse `[[note-A]]` and `[[note-B]]`. Glob for matching filenames. On ambiguity (e.g. `[[<ORG-B>]]` matches both the project index and its task file):
- Prefer project index over task file (respects the canonical-index rule).
- Prefer exact filename over substring.
- If still ambiguous, ask once. Don't guess.

### 2. Scope each neighborhood

Per resolved note, collect:
- **Backlinks**: every note wikilinking to it.
- **Outgoing links**: every wikilink in its body.
- **Tag-overlap targets**: notes sharing ≥1 frontmatter tag.
- **Folder-parent context**: the folder's index note.
- **`related:` frontmatter**: explicit list.

`--depth surface` stops here. `--depth deep` adds one-hop-out from each.

### 3. Find overlap

Compare neighborhoods for:
- **Shared concepts**: notes in both.
- **Shared tags**: frontmatter tags in common.
- **Shared stakeholders**: people mentioned in both (<PERSON-A>, <PERSON-C>, <PERSON-H>, Dad, <PERSON-D>, <PERSON-I>, <PERSON-F>).
- **Shared structural patterns**: both are proposals; both reference same hub; both have matching section skeletons.
- **Bridge candidates**: notes sitting between A's and B's neighborhoods that link to both — strongest signal.

`--via <intermediate>` restricts bridge search to paths through that note.

### 4. Type each connection

| Type | Meaning |
|---|---|
| **Structural analogy** | Structurally-similar situations in different domains. (e.g. `[[<person-h>-funnel]]` and `[[<ORG-E>]]` both = expert-to-audience translation.) |
| **Transfer opportunity** | Technique from A plausibly works in B's domain. (e.g. Morgen-MCP NL-date-parser → literature-note timestamp parser.) |
| **Collision idea** | A × B = genuinely new thing. (e.g. `[[POETRY]]` × `[[morgen-mcp]]` → scheduled weekly poem-draft prompt.) |

Reject connections that don't fit these three. "Both are projects" is not a connection.

### 5. Render

```
# Connect: [[note-A]] ↔ [[note-B]]

Resolved: <full/path/note-A.md> ↔ <full/path/note-B.md>
Depth: surface | deep
Via: [[intermediate]] (if flag set)

---

## 1. <headline> — [structural analogy]
Both notes describe <X>. In A it manifests as <Y>. In B as <Z>.
Bridge candidate: `[[shared-note]]` (linked from both).

## 2. <headline> — [transfer opportunity]
Technique in A: <T>. Would apply to B because <reason>.
Constraint: <what blocks a naive copy>.

## 3. <headline> — [collision idea]
A × B = <new thing>. Not present in vault yet.
If persisting, copy this block into a fleeting capture in `02-Sources/` (the pre-mogging `01-Fleeting/` folder was killed on 2026-04-16; fleeting thoughts now land alongside sources).

---

## Bridge notes worth reading
- `[[bridge-1]]` — linked from both; sits at <folder>
- `[[bridge-2]]` — tag-shared via #tag

## What's absent
The neighborhoods don't overlap on: <dimension>. Could be signal (genuinely orthogonal) or gap (missing bridge note).
```

Cap at 5 connections. If only 2 are real, emit 2.

## Tone

Neutral and concrete. No "interesting!" filler. Every claim grounded in a file both neighborhoods touch. Stretches get labeled `[speculative]`.

## Edge Cases

- **No overlap at any depth**: emit `[NO BRIDGE FOUND]` plus one line: "Neighborhoods are disjoint. Genuinely unrelated, or a missing intermediate concept." Do not manufacture.
- **Redundant notes (>80% overlap)**: output `[REDUNDANT] Same thing, different angles. Suggest merging via /wiki.`
- **Stub note (<200 words or frontmatter-only)**: refuse. Output `[STUB DETECTED] [[note-name]] too thin to connect. Expand first.`
- **Self-connect**: `[SAME NOTE] Nothing to bridge.`
- **Missing note**: fuzzy-suggest 3 closest filenames, ask which one. Don't guess.
- **Hub-index inflation** (e.g. `[[<ORG-A>]]` has 60+ backlinks): down-weight generic hub backlinks. Require ≥1 non-hub bridge for a connection to rank.

## Soft-Call Format (called by /emerge or /challenge)

Single-line output for programmatic callers:
```
CONNECT: A ↔ B | bridges: 3 | types: structural, transfer | strongest: [[x]]
```

## Why Read-Only Is Load-Bearing

`/wiki` persists concepts; `/emerge --promote` turns patterns into notes. Writing here would duplicate those flows and pollute the vault with cheap bridges. Manual copy-paste is the quality gate.
