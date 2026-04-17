# Contributing

Thanks for considering a contribution. This repo is small, opinionated, and intentionally kept to a narrow surface area. The contribution rules below exist to keep it that way.

## Before you start

**Open an issue first for anything larger than a typo.** A bug report, a new skill idea, a folder-structure change, a rule in a `why-not-*.md` — if it is more than a spelling fix, file an issue and wait for a discussion thread before writing code. This has saved contributors (and me) hours on pull requests that turned out to not fit the design. One paragraph is enough. You do not need to write a proposal document.

**Read the philosophy.** [`PHILOSOPHY.md`](PHILOSOPHY.md) explains the four-regime model, the tier system, and why this pack draws the lines where it does. About half of the rejected PRs in comparable packs ask for features that conflict with the regime model; knowing the model up front saves that round-trip.

## Pull request rules

**One skill per PR.** If you are adding `/foo` and also fixing a bug in `/save`, those are two PRs. Skills are the natural unit of review in this pack and mixing them makes reviews longer and riskier to revert.

**No breaking changes without a major version bump.** Anything that changes a frontmatter key, a folder role, a command name, or the `[bot:*]` commit prefix convention is a breaking change. Breaking changes require the version in `.claude-plugin/plugin.json` to go from `0.x.y` to `1.0.0` (or from `1.x.y` to `2.0.0`) and an entry in `CHANGELOG.md` under a `### Breaking` heading. We do not ship breaking changes silently.

**Every PR runs the full test harness.** From the repo root: `bash tests/run-all.sh`. The harness creates a known-state vault fixture in a temp directory, runs every skill against it, and diffs the output against expected-state files in `tests/expected/`. If your change modifies output, update the expected files in the same PR.

**Direct push to `main` is the maintainer default, not the contributor default.** This repo lives under `lorecraft-io` where maintainers push directly to `main` by policy. Contributor PRs are still required to target `main` through review. The direct-push policy does not mean "anyone can push" — it means "once merged, the change is live, no staging branch."

## How to add a new `/c*` skill

1. **Decide on the regime it writes into.** A skill that only reads and reports (like `/tether --dry-run`) has no regime concern. A skill that writes must declare its target regime in the SKILL.md frontmatter as `regime: HUMAN|PROJECT|SYNC|LLM-COMPILED`. SYNC is reserved and should not be a write target outside the sync pipeline; PRs proposing a SYNC-writer will be rejected on sight.

2. **Create the skill directory.** `mkdir -p skills/<name>/references && touch skills/<name>/SKILL.md`. If the skill needs reference docs (a schema, a template), put them under `skills/<name>/references/`. Shared schemas that multiple skills read go under `skills/save/references/wiki-schema.md` — do not create parallel copies.

3. **Write the SKILL.md.** Frontmatter must include `name`, `description`, `allowed-tools`, and `regime`. Body must include: (a) invocation syntax, (b) mandatory dry-run preview description, (c) worked example, (d) edge cases and refusals. Cross-reference `wiki-schema.md` for any frontmatter keys or folder roles.

4. **Register it in `plugin.json`.** Add an entry to the `skills` array. If the skill should also have a slash command, add a wrapper in `commands/<name>.md`.

5. **Write tests.** At minimum, one happy-path test and one refusal test (invalid input, missing prerequisite, regime violation — pick the most likely failure). Place in `tests/<name>/`.

6. **Update the README command table.** The table in `README.md` must include every public slash command. If yours isn't listed, it isn't discoverable.

## How to propose an architecture change

Open an issue tagged `architecture`. Include: the problem you are trying to solve, why existing skills cannot solve it, the regime implications, and a sketch of the change. I will either agree and mark it `accepted` (meaning a PR would be welcome) or disagree and mark it `wontfix` with a reason. Do not write the PR before the issue is `accepted` — I have rejected architecturally-sound PRs that conflicted with upcoming changes not yet in the repo, and that is wasteful for everyone.

**Rule-level changes** (a new rule in `PHILOSOPHY.md`, a new regime, a new frontmatter key) are architecture changes. **Command surface changes** (a new slash command that does something no existing command does) are also architecture changes. **Implementation changes** within an existing skill are not — those are normal PRs.

## What not to PR

- Anything that introduces a dependency on a specific task manager other than the Obsidian Tasks plugin. This pack deliberately does not integrate with paid task managers and will not.
- Anything that removes the `[bot:*]` commit prefix convention. That prefix is load-bearing for downstream sync filters.
- Anything that writes to a SYNC regime file outside a declared sync pipeline.
- Features that require a vector database or an external search index. The pack is compilation-only by design; tier 3 retrieval-memory is explicitly deferred.

## Licensing

Contributions are made under the same MIT license as the repo. By opening a PR you agree to that. See [`LICENSE`](LICENSE).
