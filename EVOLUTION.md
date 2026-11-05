# 2ndBrain-mogging: how it got here

My words are quoted as I wrote or said them, typos fixed, nothing else. Commit hashes are from this repo. "Private note" means a dated record I keep offline.

## 1. The short version

I had a second brain called 2ndBrain-maxxing. It was a modded copy of one system, and half its folders were dead weight. I studied four more, kept what earned its keep from all five, cut the rest, and renamed it, because the name is the point. It's been running my real vault since April 2026.

Then came the part nobody films. I scrubbed it for public release, audited away everything its own docs had made up, and on November 1 turned the rules I can't afford to lose into code with real tests. On November 4 I went after every way the installer could lose your data, using throwaway vaults, and shipped the fixes once CI passed on Ubuntu and macOS.

On November 5 I mogged my own vault again. `02-Sources` and `03-Concepts` became one `02-Library`, the folders closed up to run 01 through 04, chat folders became `!!conversations`, and a fresh install shrank to the bare minimum plus a guide you delete. The pack shipped the same layout the same day.

## 2. Origin, in my words

From the README:

"I wanted a second brain. So I built one."

"So I merged them. I took what earned its keep from each of the five, threw out what didn't"

"So: we went from maxxing to absolutely **mogging** everybody."

From my content notes, the thesis:

"I studied 5 different Obsidian systems. I kept only what worked. That's why it's called Mogging, not Maxxing."

"Maxxing = accumulation." "Mogging = synthesis + subtraction."

Seven months later, looking at my own vault (private note, November 5, 2026):

"I'm also wondering if 03-Concepts is actually useful and 02-Sources is actually useful, and if maybe it would be better to potentially merge them into projects somehow or make them the same folder or something?"

"I agree with this, let's go with the 02-Library, but we also will need to do some broader things when doing that, like fixing the 2ndBrain git so the readme and actual code of it and whatever is fully updated"

"Also I want to call it !!conversations probably so that it's not in the middle of the pack everywhere like it is now"

And on what a new install should get:

"I don't want it to create the folders for people when they DL it, except VAULT, and have the VAULT md in there"

"The only thing that should go in otherwise is a readme with example folder structures that explain how they should structure things and an example structure grid inside of it, and you can encourage them to delete it later if they want to, and also need to show the things that never get deleted."

## 3. Timeline

| Date (2026) | What happened | Evidence |
|---|---|---|
| Apr 16 | Scaffold, after two design swarms (15 and 5 agents) | `16359bb` |
| Apr 16 | v0.1.0: 10 skills, 4 agents, installer, docs, tests | `5171161` |
| Apr 16 | My own vault moves onto it the same evening | Private note |
| Apr 17 | v0.1.1: first PII scrub | `35c9ff2` |
| Apr 17 | v0.1.2: reverts the scrub's own damage | `a213526` |
| Apr 20 | Opt-in self-learning tier | `1e9bce2` |
| Apr 20 | README rewrite in my voice, plus two importers | `7a2bcbd` |
| Apr 20 | Proper attribution for Jens Heitmann | `e54a9b0` |
| Apr 20 | Removes made-up precision from the README | `4a6112e` |
| Apr 20 | 15-agent fix pass: 50+ audit findings | `272b19b` |
| Apr 22 | CI: shell tests, ShellCheck, Dependabot | `a5d728c` |
| Apr 25 | Bugs from a real install call | `f0f0943` |
| May 8 | Folders renumbered, conversations moved under projects | `1056ec7` |
| May 21 | `/vault-coach` and a setup guide | `90e1bd3` |
| Jul 20 | One-line updater | `dcc3ee1` |
| Aug 7 | Third-party vault skill packs, pinned | `5856159` |
| Aug 7 | Opt-in research tier | `4c7c6c4` |
| Aug 17 | Finishes the placeholder scrub | `cc0e6ce` |
| Nov 1 | A run with skipped tests stops calling itself ALL GREEN | `8ee4fac` |
| Nov 1 | The four skipped test files get real tests, plus an opt-in guard | `ebb409e` |
| Nov 1 | Opt-in memory tier | `7db3417` |
| Nov 1 | Essence and build-history docs | `cfb6d24` |
| Nov 2 | The onboarding test reads the installer's real exit code | `29cd009` |
| Nov 4 | Data preservation and helper locking, released once CI passed on Ubuntu and macOS | `72b8be7` |
| Nov 5 | Library v2: `02-Sources` and `03-Concepts` merge into `02-Library`, and the gate refuses writes to retired folders | `d0b01c8`, `e3360be`, `456aabb` |
| Nov 5 | Migration script for existing vaults | `b9bee1c`, `6fbabb2`, `57ce053` |
| Nov 5 | Renumber to `03-Index` and `04-Tasks` | `c61af9b` |
| Nov 5 | Vault root down to `CLAUDE.md`, `AGENTS.md` and `SOUL.md` | `5af31a6` |
| Nov 5 | `obsidian-mcp` and `defuddle` pinned | `e2bf2d3` |
| Nov 5 | Chat folders become `!!conversations`, reports move to `VAULT/REPORTS` | `583daa7` |
| Nov 5 | Catch-all, vault log and reports folder made on first use | `9d67eff` |
| Nov 5 | Minimal install plus a deletable layout guide | `1f445da`, `8a46f7e` |
| Nov 5 | Private names out of the skill examples | `01efd82` |
| Nov 5 | Docs brought in line with the installer and the agents | `2df10fe`, `3c8af88`, `523fe9a`, `196e8f8` |
| Nov 5 | History rewritten to take a client name out of old skill examples, so every hash after the first commit changed | The hashes in this file |
| Nov 5 | Security reports go through GitHub's private reporting | `96ea09c` |

## 4. Round by round

### Round 1: pick the five (April 16)
- **Built:** two swarms compared the systems. Karpathy gave me compile instead of retrieve. Jens Heitmann gave me the `/save` + `/wiki` core. eugeniu gave me the thinking tools and the agent schedule. AgriciDaniel gave me `/autoresearch` and `/canvas`. NicholasSpisak gave me the source-page template and discuss-before-write. The four-regime `owner:` model is mine. `docs/CREDITS.md` itemizes all of it.
- **Killed:** four folders.
- **Wanted next:** running it on my real vault.

### Round 2: make it public-safe (April 17)
- **Built:** a scrub replacing real names with stable placeholders.
- **Broke:** the scrub corrupted ordinary words where a name was a substring.
- **Fixed:** `a213526`.
- **Wanted next:** a real README, in my voice (`7a2bcbd`).

### Round 3: audit what it claims (April 20)
- **Tested:** a 5-agent audit, about 50 findings.
- **Broke:** `vault-template/` described fictional skills. The README had fake 200/800 precision. An attribution to a project was wrong.
- **Fixed:** `272b19b` with 14 workers and a validator at 19 of 19 checks, then `4a6112e` and `f1a017c`. Also a jq merge bug that broke installing the self-learning hooks (`2a9f7ea`) and invalid flags on the scheduled agents (`9d0667a`).
- **Wanted next:** someone other than me installing it.

### Round 4: someone else installs it (April 22 to 25)
- **Tested:** a real install call.
- **Broke:** the install needed two passes, a missing vault folder bailed out, there was a root-owned npm cache, and a link had gone stale.
- **Fixed:** `f0f0943`, plus new `doctor` checks.
- **Wanted next:** a coach for new users, which became `/vault-coach` (`90e1bd3`).

### Round 5: keep running (May 8 to September 21)
- **Built:** a folder restructure, the updater, skill packs, the research tier.
- **Tested:** daily, on my vault.
- **Broke:** the May 8 restructure left stale paths behind, cleaned up through May 13. A bare `log.md` from `/autoresearch` landed in the wrong folder (`8910af5`).
- **Wanted next:** proof that the rules hold, beyond my say-so.

### Round 6: make the rules real (November 1 and 2)
- **Tested:** `tests/run_all.sh` printed ALL GREEN with 4 of 8 test files skipped, because those skills are instructions with nothing to run.
- **Fixed:** `8ee4fac` makes any skip end on PARTIAL. `ebb409e` puts the rules in code, in `bin/save`, `bin/wiki`, `bin/aliases` and `bin/lib/vault-gate.sh`, and tests that code against fixtures in a temp vault. CI runs `--strict`, so a skip fails the build. `--with-guard` adds a hook that blocks a Write or Edit that breaks a task ID, and holds `/wiki` and `/autoresearch` to their scope.
- **Broke:** `/save` and `wiki-schema.md` told the model to mint a UUIDv4 for new tasks, and the sync's parser ignores anything but `m-XXXXXXXX`, so those tasks stranded. Fixed in the same commit. The next day I found the onboarding test checked the installer's exit code after `|| true`, so that check could never fail (`29cd009`).
- **Built:** `--with-memory` and `bin/memory` (`7db3417`): decay, promotion, and what was true when, with frontmatter as the only data model. It's the smallest version I could stand behind. It rewrites only `owner: wiki` and `owner: llm` frontmatter, with `--apply`, after a backup. Other notes get a proposal.
- **Wanted next:** to attack the installer the way a stranger's machine would.

### Round 7: preserve existing data (November 4)
- **Tested:** the installer, uninstaller, updater, importers and every write path against disposable vaults and fixture homes.
- **Broke:** the installer could delete an existing memory directory. Uninstall could restore stale settings and delete backups. Settings files with two JSON roots, or a scalar before an object, got accepted. Hook processes doing read-modify-write on the same helper state could lose each other's updates, and consolidation cleared pending insights before the store write, so a crash lost them.
- **Fixed:** preservation first, then archive staging, update persistence, quoted paths, task previews, atomic frontmatter writes and helper JSON publication. Settings must now be exactly one JSON object. Helper writers share a bounded lock, and consolidation keeps pending lines until the publish lands. The scheduled templates also needed valid XML and real manifest paths. All of it is `72b8be7`.
- **Tested after:** 13 of 13 test files strict, the original 357 assertions plus 38 data-safety tests and 24 helper concurrency tests. A `memory promote` dry run over 3,000 dependency files went from a 2.1216-second median to 0.1812 seconds with identical output. The [maintenance record](docs/MAINTENANCE-2026-11-04.md) and [helper state notes](docs/HELPER-STATE.md) have the details.
- **Shipped:** pushed to main the same day. The macOS CI runners got cancelled for capacity with zero steps run, a rerun passed, and Linux passed first time.
- **Wanted next:** the folder layout itself.

### Round 8: Library v2 (November 5)
- **Built:** `02-Sources` and `03-Concepts` merged into `02-Library` with `people/`, `tools/`, `ideas/` and `sources/`. `04-Index` became `03-Index` and `05-Tasks` became `04-Tasks`, so the numbers run 01 to 04 with no gaps. A source that belongs to one project lives in that project's `notes/`. The vault root holds only `CLAUDE.md`, `AGENTS.md` and `SOUL.md`. Chat folders became `!!conversations`, and agent reports moved out to `01-Projects/VAULT/REPORTS/`.
- **Built:** `scripts/migrate-to-library.sh` for everyone already on the old layout. It's a dry run by default, backs up first, refuses if a destination exists, uses `git mv` in a git vault so a tasks submodule follows, and rewrites task queries without touching a task line.
- **Fixed as code:** the gate now refuses writes into every retired folder (`d0b01c8`), so the layout rule holds even when a model forgets it.
- **Broke:** `/safetycheck` flagged that `obsidian-mcp` and `defuddle` ran unpinned through `npx -y`, which means whatever npm served that day ran in every session. Pinned in `e2bf2d3`.
- **Tested:** a new `test_migrate_to_library` suite, including a vault whose `05-Tasks` is a real git submodule. Every test file passed before and after.
- **Wanted next:** a first install that doesn't hand you folders you'll never use.

### Round 9: a fresh install stays small (November 5)
- **Built:** the template dropped its three example projects, `INCUBATOR/`, `MISC/`, the vault log and the reports folder. A new vault gets `01-Projects/VAULT/VAULT.md`, the four Library folders, two index notes, the task hub, the three root files and a `README.md` layout guide: house rules, example trees for a small and a busy vault, a structure grid, and a "Never delete these" list. It's only seeded into a vault with no numbered folders, so an update never brings it back after you delete it (`1f445da`).
- **Built:** the writers make what they need on first use. `/save` creates the catch-all project, hub note and all. The agents create `VAULT/REPORTS/`. `/wiki` finds an existing log anywhere under `VAULT/` before making one (`9d67eff`).
- **Broke:** the new onboarding test used `ls | grep`, which ShellCheck flags, so the lint job failed on `1f445da`. Fixed in `8a46f7e`.
- **Fixed:** a docs pass against the real installer. The CLAUDE.md block every install writes named agent reports that don't exist and called the morning agent opt-in (`3c8af88`). The research tier printed mid-install instead of in the summary (`523fe9a`). The README's install order skipped steps, and the helper count was 11 when there are 13 (`196e8f8`). `/tether` could treat files inside a `REPO/` checkout as vault notes (`2df10fe`). A client name and my first name were still in the skill examples (`01efd82`).
- **Tested:** 14 of 14 test files strict in CI on Ubuntu and macOS, before and after the history rewrite, last at `96ea09c`.

## 5. Feature family tree

```
2ndBrain-maxxing, one system lightly modded
└─ half the folders doing nothing → try four more systems
   └─ mogging: best of five, cut the rest (Apr 16)
      ├─ /save + /wiki core → importers → /backfill
      ├─ thinking tools → /challenge, /emerge, /connect → /tether
      ├─ scheduled agents → reports → VAULT/REPORTS (Nov 5)
      ├─ owner: regimes → vault-gate.sh → --with-guard (Nov 1)
      │                                └─ retired-folder refusals (Nov 5)
      ├─ PHILOSOPHY tier 3 → --with-memory (Nov 1)
      ├─ public release → scrubs → placeholders → private names out (Nov 5)
      ├─ real install call → doctor → /vault-coach → minimal install + layout guide (Nov 5)
      └─ ALL GREEN with skips → --strict CI → data-safety tests (Nov 4)
   my own vault reorg (Nov 5) → Library v2 → migrate-to-library.sh
```

## 6. Test log

| When | What | Result | Where |
|---|---|---|---|
| Apr 20 | Fix pass validator | 19 of 19 checks | `272b19b` |
| Apr 22 | CI added | Shell tests, ShellCheck, Dependabot | `a5d728c` |
| Nov 1, before the fixes | `tests/run_all.sh` | 8 files: 4 pass, 4 skip, 91 assertions | Local run |
| Nov 1, `7db3417`, fresh clone | `tests/run_all.sh --strict` | 11 of 11 files, 357 assertions, 0 skip | Local run |
| Nov 4, local branch | Strict suite plus new integration tests | 12 of 12 files: 357 assertions plus 35 new tests | Maintenance record |
| Nov 4, `72b8be7` | Strict suite in CI, Ubuntu and macOS | 13 of 13 files: 357 assertions, 38 data-safety tests, 24 helper tests | GitHub Actions |
| Nov 4 | `memory promote` dry run, 3,000 dependency files, 3 runs each | Median 2.1216 s before, 0.1812 s after, same output | Maintenance record |
| Nov 5, `1f445da` | Lint | Failed on ShellCheck SC2010 | GitHub Actions |
| Nov 5, `96ea09c` | Strict suite in CI, Ubuntu and macOS | 14 of 14 files: 546 shell assertions, 38 data-safety tests, 24 helper tests | GitHub Actions |

The shell suites at `96ea09c`: `aliases_bootstrap` 20, `discuss_before_write` 9, `guard_install` 18, `memory_tier` 98, `migrate_to_library` 97, `obsidian_mcp` 10, `onboarding` 110, `preflight` 16, `run_all_summary` 15, `scope_guards` 81, `uuid_preservation` 58, `vault_skill_packs` 14. The other two files, `data_safety` and `helper_concurrency`, run the Python tests.

The November 5 history rewrite changed every hash after the first commit. The hashes in this file are the current ones. The Actions tab lists runs from before the rewrite under their old hashes, on trees that differ only in that client name.

What none of these exercise: a live Claude session, a real Obsidian app, launchd firing a real scheduled agent, or a live task sync. The tests run on disposable homes and vaults with those mocked.

## 7. Roads not taken

- **Vector search.** "There is no vector index in this repo." Compile beats retrieve for a personal vault, and I'd make that trade again.
- **A full memory lifecycle.** No reasoner, no contradiction detection, no inference, no graph store, and nothing runs the memory tier on a schedule. `PHILOSOPHY.md` says so.
- **`/bridge`** from eugeniu's set, dropped.
- **Inbox, Fleeting, Templates, Assets.** Killed. Don't bring them back.
- **Separate `02-Sources` and `03-Concepts`.** Merged into `02-Library`, and the gate now refuses writes to them.
- **Example projects in the template.** A new vault starts with `VAULT/` only. Your projects have your names.
- **Keeping the name.** 2ndBrain-maxxing got left behind.

## 8. Credits

- **Karpathy, Jens Heitmann, eugeniu, AgriciDaniel, NicholasSpisak:** the ideas. `docs/CREDITS.md` itemizes what came from whom.
- **ruvnet:** the vendored `helpers/`, through FidgetFlo. `NOTICE` has the chain.
- **kepano:** the pinned Obsidian skill packs.

## 9. Sources

- Git log of `fidgetcoding/2ndBrain-mogging`, and the bodies of the commits above.
- `README.md`, `PHILOSOPHY.md`, `CHANGELOG.md`, `MIGRATION.md`, `NOTICE`, `LICENSE`, `docs/CREDITS.md`, `docs/MAINTENANCE-2026-11-04.md`, `docs/HELPER-STATE.md`, `why-not-*.md`, `tests/`.
- CI runs on the repo's Actions tab.
- Private notes from the April 16 design, the April 20 audit, the November 4 maintenance and release records, and the November 5 vault reorg session.
