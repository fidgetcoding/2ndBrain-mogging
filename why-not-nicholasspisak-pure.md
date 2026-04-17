# Why not NicholasSpisak's pack directly

[NicholasSpisak/second-brain](https://github.com/NicholasSpisak/second-brain) is the discipline-layer reference. It is a minimal, faithful Karpathy-port with an unusually sharp set of rules about what the LLM is and is not allowed to do when writing into the vault. Where NulightJens's pack is minimal-by-absence, NicholasSpisak's is minimal-by-conviction — every rule is written down and the ruleset itself is the product.

I borrowed more rules and fewer features from this pack than from any other upstream. The features it has are a strict subset of what I wanted to ship; the rules it has are ones I wanted in my pack verbatim.

## What I kept from it

**The source-page template.** NicholasSpisak defines a canonical template for Sources notes — required frontmatter keys (title, date, url, tags, related), expected body structure (summary, key ideas in the writer's words, open questions), and a discipline that the source note is pure factual content with no interpretation. I ported this template directly. My `02-Literature/LIT-*.md` files follow his template almost unchanged.

**Discuss-before-write etiquette.** Before `/save` writes anything, NicholasSpisak's pack presents what it is about to do and waits for the user to confirm. This is the seed of what I expanded into the full dry-run preview table. The underlying principle — never write without announcing intent first — is his.

**The "factual content goes in Sources only" rule.** This is a sharp distinction. Interpretation, inference, synthesis, opinion — all go in Wiki or Permanent notes. The Sources folder is uninterpreted fact. If the LLM wants to say "this implies X," that goes in a compiled wiki note, not in the source. This is a load-bearing invariant for the compilation-over-retrieval model to work — sources need to stay accreted and factual or the re-compilation loop degrades. I enforce this rule in `/save` by routing dictation and commentary to different destinations than verbatim captures.

**Prefer-update-over-create.** When `/save` encounters content that belongs alongside an existing note, NicholasSpisak's rule is: append to the existing note, do not create a new one. This keeps the graph dense and avoids fragmenting a topic across three near-duplicates. I kept this rule and extended it — my `/save` checks for existing notes matching the top-scoring alias and appends rather than creating unless the operator explicitly asks for a new file.

**The bash test-harness pattern.** NicholasSpisak ships his tests as plain bash scripts in `tests/`, each one invoking the skill against a known-state vault fixture and asserting on the output. No test framework, no dependencies, no runner. The whole thing reads top-to-bottom in an afternoon. I copied the pattern for my own `tests/` directory. It turns out you do not need Jest to test markdown-writing skills — you need `diff` and `grep`.

**`wiki-schema.md` as single source of truth.** NicholasSpisak puts all the frontmatter keys, folder roles, and linking grammar in one file — `wiki-schema.md` — and both `/save` and `/wiki` read it. Changes to the schema happen in exactly one place. I ported this directly. My `skills/save/references/wiki-schema.md` is the same shape as his, with my keys substituted for his.

## What I added beyond it

**Ten commands vs. four.** NicholasSpisak ships `/save`, `/wiki`, and two supporting commands. I ship ten. The six extra skills are all tier-2 thinking tools and infrastructure concerns (classifier, tether audit, backfill) that his pack does not address because it is operating under Karpathy-minimal scope.

**Thinking tools.** `/challenge`, `/emerge`, `/connect`, `/autoresearch` — none of these exist in NicholasSpisak's pack. They are net-new in this pack relative to his.

**Scheduled agents.** The morning / nightly / weekly / health cadence is not in his pack. He runs everything synchronously on user invocation; I run four background jobs via launchd.

**Regime awareness.** His pack has two regimes: HUMAN-authored and LLM-compiled. I have four (HUMAN, PROJECT, SYNC, LLM-COMPILED). The two he doesn't have — PROJECT and SYNC — are the ones that matter in an operator vault with live sync pipelines. For a solo reader-writer vault his two-regime model is sufficient.

## When NicholasSpisak's pack is still better

If you want the most disciplined, rule-forward, provably-minimal second brain in the Claude Code ecosystem — his pack is it. The whole thing reads as prose, every rule is justified, and the code surface is small enough to audit in a sitting. If what you value is fewer moving parts and sharper invariants, his pack has both in higher concentration than mine.

His pack is credited in [`docs/CREDITS.md`](docs/CREDITS.md) and analyzed in [`docs/foundations/05-extensions-analysis.md`](docs/foundations/05-extensions-analysis.md) alongside the other Karpathy extensions.
