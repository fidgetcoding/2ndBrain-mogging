---
name: autoresearch
description: Three-round web research loop that decomposes a topic, gathers sources, gap-fills contradictions, and emits vault-ready literature + concept notes with confidence labels. Ported from AgriciDaniel with source-freshness hardening, SSRF guards, and a Karpathy factual-only rule for literature notes.
allowed-tools: Read, Write, WebSearch, WebFetch, Grep, Glob
---

# /autoresearch

Structured web research for the 2ndBrain vault. Decomposes a topic into angles, runs a bounded multi-round search loop, writes per-source literature notes + per-concept permanent notes, then reconciles everything into a master synthesis. Strict source-freshness and SSRF policies keep the research clean and safe.

## Invocation

```
/autoresearch "topic" [--rounds N=3] [--depth shallow|standard|deep] [--existing-check]
```

- `topic` — required string; the research question or concept.
- `--rounds` — max rounds 1-3 (default 3). Round 3 only runs if Round 2 still has unresolved contradictions.
- `--depth` — `shallow` (1 search per angle, 1 fetch), `standard` (2-3 searches, 2 fetches, default), `deep` (3 searches, 3 fetches + Round 3 auto-on).
- `--existing-check` — force Round 0 even if `log.md` shows recent coverage.

## Pipeline

### Round 0 — Existing-Vault Check

Before burning any web calls, Grep the vault for adjacent notes.

1. Slugify topic into candidate filenames.
2. Grep `03-Concepts/`, `02-Sources/`, and `04-Index/Index.md` for the slug and its top-3 synonyms.
3. If 3+ notes match with recent mtime (<90 days), surface: `vault has N adjacent notes — proceed / refine / abort?`
4. If user picks `refine`, narrow the topic to the missing gap and restart Round 0.
5. If user picks `abort`, exit without network calls.
6. If user picks `proceed` or vault is empty, continue to Round 1.

Round 0 is free — it never hits the network and never writes files. Its only job is to prevent duplicate work and keep the vault graph tight.

### Round 1 — Broad Search

Decompose the topic into 3-5 angles. An angle is a distinct sub-question or stakeholder lens (e.g. for "retrieval-augmented generation" → mechanism, evaluation, failure modes, production deployments, recent variants).

1. Write angles as a checklist inside the synthesis draft.
2. For each angle, run 2-3 WebSearch queries. Vary phrasing; prefer specific over generic.
3. For each search, WebFetch the top 2-3 results that pass the source policy (below).
4. Summarize each fetched source into a candidate `02-Sources/LIT-{slug}.md` in memory. Do not write yet — write only survives Round 2 reconciliation.

Budget: `standard` depth → ~20 fetches max, `deep` → ~40 fetches max. Never exceed 50 fetches in a single invocation.

### Round 2 — Gap Fill

Scan all Round 1 summaries for:

- **Contradictions** — two sources claim incompatible facts.
- **Missing primitives** — claims referenced but not defined (e.g. an algorithm named but never explained).
- **Unclear dates or provenance** — an assertion with no year, author, or institution.

For each gap, run at most 5 targeted queries (total across the round, not per-gap). Prefer primary sources: the original paper, the official docs, the first-party blog. If a gap cannot be resolved within budget, emit a `> [!gap]` callout in the synthesis and move on — do NOT hedge in the body text.

### Round 3 — Synthesis Check (Optional)

Runs only if Round 2 leaves ≥1 unresolved contradiction. Re-query each contradiction with the sharpest phrasing you can generate, weigh sources by authority (primary > secondary > tertiary), and either resolve or explicitly mark `> [!gap] unresolved: Source A says X, Source B says Y, both credible as of <date>`.

## Source Policy

**Prefer:**

- `.edu`, `.gov` domains
- Official project docs (`docs.*`, `*.dev/docs`, vendor knowledge bases)
- Primary sources (original papers on arXiv, RFCs, first-party blogs)
- Published <2 years ago, unless the topic is foundational (math, classical CS, established science)
- Named authors with visible credentials

**Exclude:**

- Reddit, Hacker News comments, X/Twitter threads, Discord transcripts
- Content farms and SEO aggregators (`*.io/blog` with no author, recycled lists)
- Undated pages where publish date cannot be inferred from `<meta>` or URL
- Machine-translated content where provenance is unclear
- Any page served over plain `http://` (see URL safety)

When in doubt, cite the source but mark the claim `low` confidence.

## Confidence Labels

Every non-trivial claim in the output gets a confidence tag:

- `high` — two or more independent authoritative sources agree.
- `medium` — one strong source, no contradictions.
- `low` — speculative, single weak source, or inferred.

Tags render inline: `LLM inference latency scales near-linearly with context length [medium]`. Never hedge linguistically — do not write "it seems" or "arguably". Use the label.

## Output Structure

Per source → `02-Sources/LIT-{slug}.md`:

- YAML frontmatter: `title`, `author`, `source_url`, `fetched_date`, `publish_date`, `confidence`, `type: literature`.
- **Karpathy rule:** literature notes are factual extraction only. No synthesis, no opinions, no connections. If it wasn't on the page, it does not belong here.
- Structure: summary (≤200 words) → key facts as bullets → verbatim quotes for load-bearing claims.
- Cap at 200 lines. If a source is genuinely larger, split into `LIT-{slug}-part-2.md`.

Per concept → `03-Concepts/{slug}.md` (create or update):

- Declarative present tense. Explain the concept as if to a colleague.
- Every factual claim carries an inline citation `(Source: [[LIT-{slug}]])` and a confidence label.
- Dense wikilinks to sibling concepts and upstream MOCs.
- Update existing notes — do not duplicate. Append new facts under a `## Updates {date}` subheading if the concept exists.

Per entity (person, org, tool, place) → update wikilinks across all affected notes. Create a stub in `03-Concepts/entities/` if missing.

Master synthesis → `03-Concepts/synthesis/{topic-slug}.md`:

- The narrative answer to the original question.
- Cites every `02-Sources/LIT-*` note used.
- Ends with a `## Open Questions` section and any `> [!gap]` callouts lifted from Round 2/3.
- Links back to `04-Index/Index.md` and prepends a line to `log.md`.

## Writing Rules

- Declarative present tense. No "might", no "could arguably", no "in some cases" (use confidence labels instead).
- Citations inline as `(Source: [[Page]])` — brackets must resolve to a real `LIT-*` file in `02-Sources/`.
- `> [!gap]` callout for any admitted uncertainty.
- ≤200 lines per page. Hard cap — if content exceeds, split.
- No hedging adverbs. No filler transitions ("furthermore", "additionally"). Facts stack tightly.

## Post-Loop Housekeeping

1. Update `04-Index/Index.md` — add the synthesis note under the topic's taxonomy branch, create a new branch if needed.
2. Prepend a one-line entry to `log.md`: `{date} {topic-slug} — N sources, M concepts, {gap-count} gaps`.
3. If `Claude-Memory/hot.md` exists, refresh its cache block for this topic (most-recent 5 concepts + synthesis link).
4. If the topic touches an existing project, link the synthesis from the project index's **Related** section.

## URL Safety

Mandatory for every WebFetch call — no exceptions:

- Scheme whitelist: only `https://`. Reject `http://`, `file://`, `ftp://`, `data:`, `javascript:`.
- SSRF block list: reject host resolving to `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `0.0.0.0`, `::1`, fc00::/7, `.local`, `.internal`.
- Content length cap: 2 MB. Abort and log the URL if the body exceeds.
- Timeout: 30 seconds per fetch.
- Redirect cap: 10. Follow cross-origin redirects only if the destination still passes the block list.
- HTML-to-markdown: pipe through `pandoc --sandbox` or a sandboxed equivalent — never eval inline scripts.
- Sanitize: strip zero-width characters (U+200B-U+200F, U+FEFF) and normalize homoglyph-heavy strings before storing. Reject sources whose title or author contains mixed-script homoglyphs after normalization.
- PDF handling: allow PDFs up to 2 MB, extract text via `pdftotext -layout`, never execute embedded JS.

## Commit Hygiene

When a vault sync commits `/autoresearch` output, the commit message MUST start with `[bot:autoresearch]`. This matches the `08-Tasks/` sync filter and prevents W1 from re-ingesting research runs as tasks.

## Failure Modes

- **No web results for a round** → emit `> [!gap] no results for: "{query}"` in synthesis, mark the angle `confidence: low`, continue.
- **All sources fail URL safety** → abort the angle, flag in synthesis, do not write partial literature notes.
- **Vault write collision** (existing note with same slug) → append to existing under `## Updates {date}`, never overwrite.
- **Budget exhausted mid-round** → finish the current fetch, write everything gathered, mark remaining angles `incomplete` in synthesis, do not silently truncate.

## Example Trace

```
/autoresearch "JSCalendar floating datetime semantics" --depth standard

Round 0 → vault has 2 adjacent notes (LIT-rfc8984, morgen-api-quirks). proceed.
Round 1 → 4 angles × 2 searches × 2 fetches = 16 sources fetched, 12 passed source policy.
Round 2 → 2 contradictions (timezone drift, DST handling); 4 targeted queries; both resolved.
Round 3 → skipped (no unresolved contradictions).
Output → 12 LIT-* notes, 3 concept updates, 1 synthesis at 03-Concepts/synthesis/jscalendar-floating-datetime.md.
Housekeeping → Index updated, log prepended, hot.md refreshed.
Commit → [bot:autoresearch] 12 sources, 3 concepts, 0 gaps.
```

The loop is bounded, the output is vault-native, and every claim is traceable to a literature note. When in doubt: shorter rounds, stricter sources, more gap callouts, fewer hedges.
