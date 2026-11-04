# 2ndBrain-mogging: how it got here

## Short version

I had a second brain called 2ndBrain-maxxing. It was a modded copy of one system, and half its folders were dead weight. I studied four more, kept what earned its keep from all five, cut the rest, and renamed it, because the name is the point. It's been running my real vault since April 2026. Then came the part nobody films: scrubbing it for public release, auditing away everything its own docs had made up, and on 2026-11-01 turning the rules I can't afford to lose into code with real tests. Claude Code swarms did most of the writing and auditing, and I decided what stayed and what got cut.

## Origin, in my words

From the README:

"I wanted a second brain. So I built one."

"So I merged them. I took what earned its keep from each of the five, threw out what didn't"

"So: we went from maxxing to absolutely **mogging** everybody."

From my content notes, the thesis:

"I studied 5 different Obsidian systems. I kept only what worked. That's why it's called Mogging, not Maxxing."

"Maxxing = accumulation." "Mogging = synthesis + subtraction."

## Timeline

| Date | Commit | What happened |
|---|---|---|
| 2026-04-16 | `16359bb` | Scaffold, after two design swarms (15 and 5 agents) |
| 2026-04-16 | `cc59259` | v0.1.0: 10 skills, 4 agents, installer, docs, tests |
| 2026-04-17 | `b8ac8c1` | v0.1.1: first PII scrub |
| 2026-04-17 | `3bcf62c` | v0.1.2: reverts the scrub's own damage |
| 2026-04-20 | `dbdf622` | README rewrite in my voice, plus two importers |
| 2026-04-20 | `5801483` | Proper attribution for Jens Heitmann |
| 2026-04-20 | `17c6487` | Removes made-up precision from the README |
| 2026-04-20 | `136f678` | 15-agent fix pass: 50+ audit findings |
| 2026-04-22 | `6585900` | CI: test harness, shellcheck, Dependabot |
| 2026-04-25 | `ddc2d6e` | Bugs from a real install call |
| 2026-05-08 | `a8db9d1` | Folders renumbered, conversations moved under projects |
| 2026-05-21 | `698694d` | `/vault-coach` and a setup guide |
| 2026-07-20 | `e4d1b63` | One-line updater |
| 2026-08-07 | `2793430` | Third-party vault skills, pinned |
| 2026-08-07 | `26d14b6` | Opt-in research tier |
| 2026-08-17 | `6193f0d` | Finishes the placeholder scrub |
| 2026-11-01 | `f4ace9c` | A run with skipped tests stops calling itself ALL GREEN |
| 2026-11-01 | `8e25fb5` | The four skipped test files get real tests, plus an opt-in guard |
| 2026-11-01 | `79705ca` | Opt-in memory tier |

## Round by round

**Round 1: pick the five (04-16).**
Built: two swarms compared the systems. Karpathy gave me compile instead of retrieve. Jens Heitmann gave me the save-and-wiki core. eugeniu gave me the thinking tools and the agent schedule. AgriciDaniel gave me `/autoresearch` and the `owner:` discipline. NicholasSpisak gave me `/canvas`.
Killed: four folders.
What came next: running it on my real vault.

**Round 2: make it public-safe (04-17).**
Built: a scrub replacing real names with stable placeholders.
Broke: the scrub corrupted ordinary words where a name was a substring.
Fixed: `3bcf62c`.
What came next: a real README, in my voice (`dbdf622`).

**Round 3: audit what it claims (04-20).**
Tested: a 5-agent audit, about 50 findings.
Broke: `vault-template/` described fictional skills. The README had fake 200/800 precision. An attribution to a project was wrong.
Fixed: `136f678` with 14 workers and a validator at 19 of 19 checks, then `17c6487` and `9577383`. Also a jq merge bug that broke installing the self-learning hooks (`646d073`) and invalid flags on the scheduled agents (`66f8e15`).

**Round 4: someone else installs it (04-22 to 04-25).**
Tested: a real install call.
Broke: the install needed two passes, a missing vault folder bailed out, a root-owned npm cache, a stale link.
Fixed: `ddc2d6e`, plus new `doctor` checks.
What came next: a coach for new users, `/vault-coach` (`698694d`).

**Round 5: keep running (05-08 to 09-21).**
Built: folder restructure, updater, skill packs, research tier.
Broke: 05-08's restructure left stale paths behind, cleaned up through 05-13. A bare `log.md` from `/autoresearch` landed in the wrong folder (`29fdaa2`).
Tested: daily, on my vault.

**Round 6: make the rules real (11-01).**
Tested: `tests/run_all.sh` printed ALL GREEN with 4 of 8 test files skipped, because those skills are instructions with nothing to run.
Fixed: `f4ace9c` makes any skip end on PARTIAL. `8e25fb5` puts the rules in code, in `bin/save`, `bin/wiki`, `bin/aliases` and `bin/lib/vault-gate.sh`, and tests that code against fixtures in a temp vault. CI runs `--strict`, so a skip fails the build. `--with-guard` adds a hook that blocks a Write or Edit that breaks a task ID, and holds `/wiki` and `/autoresearch` to their scope.
Also broke: `/save` and `wiki-schema.md` told the model to mint a UUIDv4 for new tasks, and the sync's parser ignores anything but `m-XXXXXXXX`, so those tasks stranded. Fixed in the same commit.
Built: `--with-memory` and `bin/memory` (`79705ca`): decay, promotion, and what was true when, with frontmatter as the only data model. It's the smallest version I could stand behind. It rewrites only `owner: wiki` and `owner: llm` frontmatter, with `--apply`, after a backup. Other notes get a proposal.

**Round 7: preserve existing data (11-04, local maintenance branch).**
I tested the installer and write paths against disposable vaults. The installer could delete an existing memory directory; uninstall could restore stale settings and delete backups. I fixed preservation first, then hardened archive staging, update persistence, quoted paths, task previews, frontmatter writes, and helper JSON publication. The scheduled templates also needed valid XML and real manifest paths.

The strict suite now passes 12 of 12 files: the original 357 assertions plus 35 new integration tests, with no skips. A dependency-heavy memory scan fixture went from a 2.1216-second median to 0.1812 seconds with identical output. The [maintenance record](docs/MAINTENANCE-2026-11-04.md) records the measurements, recovery behavior, and remaining integration limits. These changes are local and have not been deployed.

## Test log

| Date | Check | Result |
|---|---|---|
| 2026-04-20 | Fix pass validator | 19 of 19 checks |
| 2026-04-22 | `6585900` CI added | Tests, shellcheck, Dependabot |
| 2026-11-01 | `tests/run_all.sh` before the fixes | 8 files: 4 pass, 4 skip, 91 assertions |
| 2026-11-01 | `tests/run_all.sh --strict` at `79705ca`, fresh clone | 11 of 11 files, 357 assertions, 0 skip |

The suites at `79705ca`: `aliases_bootstrap` 20, `discuss_before_write` 9, `guard_install` 18, `memory_tier` 94, `obsidian_mcp` 10, `onboarding` 51, `preflight` 16, `run_all_summary` 15, `scope_guards` 54, `uuid_preservation` 56, `vault_skill_packs` 14.

## Roads not taken

- **Vector search.** "There is no vector index in this repo." Compile beats retrieve for a personal vault, and I'd make that trade again.
- **A full memory lifecycle.** No reasoner, no contradiction detection, no inference, no graph store, and nothing runs the memory tier on a schedule. `PHILOSOPHY.md` says so.
- **`/bridge`** from eugeniu's set, dropped.
- **Inbox, Fleeting, Templates, Assets.** Killed. Don't bring them back.
- **Keeping the name.** 2ndBrain-maxxing got left behind.

## Credits

- **Karpathy, Jens Heitmann, eugeniu, AgriciDaniel, NicholasSpisak:** the ideas. `docs/CREDITS.md` itemizes what came from whom.
- **ruvnet:** the vendored `helpers/`, through FidgetFlo. `NOTICE` has the chain.
- **kepano:** the pinned Obsidian skill packs.

## Sources

- Git log of `fidgetcoding/2ndBrain-mogging`, and the bodies of the commits above.
- `README.md`, `PHILOSOPHY.md`, `CHANGELOG.md`, `NOTICE`, `LICENSE`, `docs/CREDITS.md`, `why-not-*.md`, `tests/`.
- CI runs on the repo's Actions tab.
- Private notes from the 2026-04-16 design and the 2026-04-20 audit.
