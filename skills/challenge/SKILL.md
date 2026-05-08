---
name: challenge
description: Adversarial vault agent. Takes an idea and argues against it using the operator's own past notes, feedback files, and Claude-Memory — surfacing contradictions, constraints, cost patterns, stakeholder conflicts, and broken dependencies. Read-only by default; writes only with --save. Use when the user says /challenge, wants a devil's advocate, wants to stress-test a pitch/plan/purchase, or asks "am I wrong about X" / "poke holes in this."
allowed-tools: Read, Grep, Glob
---

# /challenge — Adversarial Vault Agent

the operator's vault already holds the counter-arguments to most of his new ideas. He just hasn't re-read them. `/challenge` reads them for him and argues back — analytically, with citations, never with snark.

## When to Invoke

- User types `/challenge "idea text"` directly.
- User pitches a new idea and asks for pushback, red-teaming, or stress-testing.
- Before the operator ships something irreversible (signs a contract, publishes a release, commits a purchase, commits architecture).
- `/emerge` emits a candidate pattern the operator is about to promote — auto-run `/challenge` over the pattern first.

Do NOT invoke for creative work-in-progress (poetry drafts, script drafts) unless the operator explicitly asks. Creative friction kills creative flow.

## Invocation Forms

```
/challenge "charge $2k flat for <PERSON-H> funnel"
/challenge --scope <ORG-E> "pitch CMO role retainer"
/challenge --days 30 --source "add Todoist back as secondary task tool"
/challenge --save "ship Morgen MCP v0.2 without task-to-calendar gap fixed"
```

If invoked with no argument, prompt the user once: `What idea should I stress-test?` Then run the pipeline.

## Flags

| Flag | Behavior |
|---|---|
| `--scope <project>` | Restrict evidence search to a single project folder under `01-Projects/` (e.g. `--scope <ORG-E>`). Defaults to whole vault. |
| `--days N` | Only weigh evidence newer than N days. Default: no time filter, but recency always boosts ranking. |
| `--save` | Write the full report to `03-Concepts/challenges/YYYY-MM-DD-<slug>.md` and link it into `MOC-Challenges.md` if it exists. Without this flag, output is terminal-only. |
| `--source` | Verbose citation mode — every claim gets file path + line number + quoted excerpt, not just the filename. |

## Pipeline (run in order)

### 1. Resolve the idea

Parse the idea string into (a) a one-line proposition and (b) 3-6 keyword anchors. Example: *"charge $2k flat for <PERSON-H> funnel"* → proposition = commit to flat-fee pricing on <PROJECT-B> funnel; anchors = `<PERSON-H>`, `<PROJECT-B>`, `flat fee`, `pricing`, `funnel`, `retainer`.

### 2. Scope the search

If `--scope` given, restrict to that folder. Otherwise search the full vault. Always include:
- `~/.claude/projects/-2ndBrain/memory/MEMORY.md` (Claude-Memory auto-memory)
- `~/.claude/projects/-2ndBrain/memory/` individual `feedback_*.md` and `project_*.md` files
- `03-Concepts/` (refined positions; pre-mogging `03-Permanent/` was collapsed into this folder on 2026-04-16)
- `01-Projects/<scoped>/` (project-local decisions)

### 3. Gather evidence

Run four parallel passes per anchor:
- **Semantic**: Read conceptually adjacent notes (use Grep for synonyms + Glob for topic folders).
- **Keyword**: Literal match on anchors.
- **Wikilink graph**: Every note linking to or linked from resolved target notes becomes a candidate.
- **Claude-Memory scan**: Grep MEMORY.md for every anchor — these entries are gold because they already encode the operator's stated preferences.

### 4. Classify each hit

Every evidence fragment gets one of seven labels:

| Label | Meaning |
|---|---|
| `CONTRADICTS` | Direct opposition. Past note says the opposite of the proposition. |
| `CONSTRAINT` | Rule, policy, or boundary the operator set (e.g. `feedback_no_prs`, `feedback_motion_auto_schedule`). Proposition violates it. |
| `COST_PATTERN` | Evidence the operator consistently under/over-estimates cost/time/effort on similar work. |
| `STAKEHOLDER_CONFLICT` | The idea involves someone (<PERSON-A>, <PERSON-C>, <PERSON-H>, Dad, <PERSON-D>, <PERSON-I>, <PERSON-F>) whose documented preferences push back. |
| `DEPENDENCY_BROKEN` | The idea depends on something documented as broken/stalled (`google_workspace_mcp_oauth_broken`, `task-to-calendar API gap`, etc.). |
| `SUPPORTS` | Past note agrees with the proposition. Still collect these — needed for the balance check. |
| `IRRELEVANT` | Matched keyword but not meaningful. Drop from ranking. |

### 5. Rank

`score = recency_weight × source_count × specificity`

- `recency_weight`: newer notes win. A note from last week outranks a note from 2022 at same specificity.
- `source_count`: repeated stance across multiple files > single mention.
- `specificity`: a named rule (`feedback_no_prs.md`) outranks a tangential mention.

### 6. Render report

Structure the output:

```
# Challenge: <proposition>

## Verdict: <GO | PAUSE | STOP | NET-NEW>
One-paragraph summary of the strongest counter-argument.

## Strong (do not ignore)
- [CONTRADICTS] <claim> — `feedback_no_prs.md:3` "Push direct to main on all <ORG-A> repos, no branches, no PRs"
- [CONSTRAINT] <claim> — `feedback_motion_auto_schedule.md:1` ...

## Medium (worth addressing)
- [COST_PATTERN] ...

## Weak (flagged but thin)
- [STAKEHOLDER_CONFLICT] ...

## Supporting evidence (for balance)
- [SUPPORTS] ...

## Devil's advocate points (even if vault is silent)
- ...

## Open questions
- ...
```

Verdicts:
- `STOP` — at least one Strong `CONTRADICTS` or `CONSTRAINT` hit.
- `PAUSE` — only Medium hits, but enough to warrant a think.
- `GO` — only Weak or Supporting. Idea is consistent with the vault.
- `NET-NEW` — zero evidence either way. Flag as genuinely new territory.

## Tone

Analytical, not confrontational. Write like a research memo. No sarcasm, no "gotcha" framing. the operator is arguing with his past self — the job is to make that past self's strongest case, not to score points. Every claim cited with file path and line number. Never hallucinate a citation; if the vault is silent on something, say so explicitly.

## Edge Cases

- **Zero evidence**: emit `NET-NEW` verdict and pivot to 3-5 generic devil's-advocate risks. Never invent vault citations.
- **All evidence SUPPORTS**: report `GO`, then generate 3 honest devil's-advocate points labeled `[NO VAULT BASIS]`.
- **Idea too vague**: ask one clarifying question before running. Don't burn context on a fuzzy target.
- **--save with zero Strong/Medium hits**: still save, but prefix filename with `weak-`.

## Save Behavior (--save only)

Write to `03-Concepts/challenges/YYYY-MM-DD-<slug>.md` with frontmatter:

```yaml
---
type: challenge
date: 2026-04-16
idea: "<proposition>"
verdict: STOP | PAUSE | GO | NET-NEW
scope: <project or "vault">
source_count: N
---
```

Body = the rendered report. Link every cited file as `[[wikilink]]`. Add to `MOC-Challenges.md` under the correct date heading if present; do NOT create the MOC if missing.

## Cross-Skill Behavior

- Soft-call `/connect` read-only to find bridge notes between the idea and unexpected vault regions — sometimes the best counter-argument lives where the anchors don't hit.
- If `/emerge` invoked `/challenge` on a promotion candidate, emit compact output (Verdict + Strong bucket only) so `/emerge` can fold it in.
