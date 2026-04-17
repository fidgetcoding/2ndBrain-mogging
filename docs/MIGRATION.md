# Migration Runbook — Detailed

Long-form, command-first migration guide for moving from a pre-mogging 9-folder vault to the post-mogging 7-structure contract. The short version lives in the root [`MIGRATION.md`](../MIGRATION.md); this file owns per-phase commands, rollback points, edge cases, and validation queries.

## Pre-flight

### Target contract

Post-mogging canonical layout:

```
2ndBrain/
├── 01-Conversations/   # /save output, mirrors 05-Projects
├── 02-Sources/         # external inputs (renamed from 02-Literature)
├── 03-Concepts/        # atomic concepts (renamed from 03-Permanent)
├── 04-Index/           # MOCs (renamed from 04-MOC)
├── 05-Projects/        # project folders (renamed from 07-Projects), + INCUBATOR/
├── 06-Tasks/           # Obsidian Tasks hub (renamed from 08-Tasks), submodule preserved
├── Claude-Memory/      # symlink to ~/.claude/projects/.../memory/
├── AGENTS.md           # sidecar
├── CLAUDE.md           # sidecar (append-only patched)
├── CRITICAL_FACTS.md   # sidecar
├── SOUL.md             # sidecar
├── index.md            # sidecar
└── log.md              # sidecar
```

Killed folders: `00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`.

### Backup (non-negotiable)

```bash
cd /path/to/2ndBrain
git tag v0-pre-migration
git push origin v0-pre-migration
tar czf ~/Desktop/2ndBrain-backup-$(date +%Y%m%d-%H%M%S).tar.gz .
```

The tag is your full-rollback anchor. The tarball is your oh-shit anchor if git itself corrupts.

---

## Phase A — Drain + kill dead folders

### A1. Drain `00-Inbox/` and `01-Fleeting/` into legacy reports

Nothing gets deleted without a paper trail. Concatenate survivors into two legacy bundles, then remove the source folders.

```bash
mkdir -p 01-Conversations/VAULT/legacy
{ printf '# Legacy Inbox (drained %s)\n\n' "$(date +%Y-%m-%d)"; \
  for f in 00-Inbox/*.md; do [ -f "$f" ] && printf '\n\n---\n\n## %s\n\n' "$(basename "$f")" && cat "$f"; done; \
} > 01-Conversations/VAULT/legacy/inbox-drain.md

{ printf '# Legacy Fleeting (drained %s)\n\n' "$(date +%Y-%m-%d)"; \
  for f in 01-Fleeting/*.md; do [ -f "$f" ] && printf '\n\n---\n\n## %s\n\n' "$(basename "$f")" && cat "$f"; done; \
} > 01-Conversations/VAULT/legacy/fleeting-drain.md

git add 01-Conversations/VAULT/legacy/
git commit -m "phase-A-1: drain 00-Inbox + 01-Fleeting into legacy reports"
```

### A2. Kill `00-Inbox/`, `01-Fleeting/`, `05-Templates/`, `06-Assets/`

```bash
git rm -r 00-Inbox 01-Fleeting 05-Templates 06-Assets
git commit -m "phase-A-2: remove 4 killed folders (inbox, fleeting, templates, assets)"
```

**Rollback A2:** `git reset --hard HEAD~1`. The drain is preserved in A1's commit.

---

## Phase B — Rename survivors

Every rename uses `git mv` so history follows. For folders containing submodules (e.g. `08-Tasks/`), `git mv` preserves the `.gitmodules` entry automatically — no extra steps.

### B1. `02-Literature/` → `02-Sources/`

```bash
git mv 02-Literature 02-Sources
git commit -m "phase-B-1: rename 02-Literature → 02-Sources"
```

### B2. `03-Permanent/` → `03-Concepts/`

```bash
git mv 03-Permanent 03-Concepts
git commit -m "phase-B-2: rename 03-Permanent → 03-Concepts"
```

### B3. `04-MOC/` → `04-Index/`

```bash
git mv 04-MOC 04-Index
git commit -m "phase-B-3: rename 04-MOC → 04-Index"
```

### B4. `07-Projects/` → `05-Projects/`

```bash
git mv 07-Projects 05-Projects
git commit -m "phase-B-4: rename 07-Projects → 05-Projects"
```

### B5. `08-Tasks/` → `06-Tasks/` (submodule preserved)

```bash
git mv 08-Tasks 06-Tasks
git submodule status  # confirm path updated
git commit -m "phase-B-5: rename 08-Tasks → 06-Tasks (submodule preserved)"
```

If `git submodule status` still prints `08-Tasks`, run `git submodule sync` then re-commit `.gitmodules`.

**Rollback any B step:** `git reset --hard HEAD~1`. **Rollback all of Phase B:** `git reset --hard v0-pre-migration` then re-run Phase A only.

---

## Phase C — Rewrite internal references

### C1. Obsidian Tasks plugin queries: `path includes 08-Tasks` → `path includes 06-Tasks`

```bash
grep -rln 'path includes 08-Tasks' . \
  | xargs sed -i '' 's|path includes 08-Tasks|path includes 06-Tasks|g'

grep -rln 'path includes 07-Projects' . \
  | xargs sed -i '' 's|path includes 07-Projects|path includes 05-Projects|g'

git commit -am "phase-C-1: rewrite Tasks plugin path filters (08→06, 07→05)"
```

Linux users: drop the `''` after `-i`.

### C2. Killed-folder references in index files

`Home-Index.md`, `Projects-Index.md`, `04-Index/Index.md` and similar MOCs often list `[[00-Inbox]]` or `[[06-Assets]]`. These become dangling links. Sweep them:

```bash
grep -rln '\[\[00-Inbox\]\]\|\[\[01-Fleeting\]\]\|\[\[05-Templates\]\]\|\[\[06-Assets\]\]' 04-Index/
```

Open each hit and either delete the line or replace the link with the new equivalent (e.g. `[[00-Inbox]]` → `[[01-Conversations]]` when semantically appropriate). Commit: `phase-C-2: clean killed-folder refs from index files`.

### C3. Wikilinks pointing at renamed folders

```bash
grep -rln '\[\[02-Literature' . | xargs sed -i '' 's|\[\[02-Literature|[[02-Sources|g'
grep -rln '\[\[03-Permanent'  . | xargs sed -i '' 's|\[\[03-Permanent|[[03-Concepts|g'
grep -rln '\[\[04-MOC'        . | xargs sed -i '' 's|\[\[04-MOC|[[04-Index|g'
grep -rln '\[\[07-Projects'   . | xargs sed -i '' 's|\[\[07-Projects|[[05-Projects|g'
grep -rln '\[\[08-Tasks'      . | xargs sed -i '' 's|\[\[08-Tasks|[[06-Tasks|g'
git commit -am "phase-C-3: rewrite wikilinks for renamed folders"
```

---

## Phase D — Sidecars + symlink

### D1. Claude-Memory symlink (idempotent)

```bash
TARGET="$HOME/.claude/projects/-Users-$(whoami)-Desktop-WORK-OBSIDIAN-2ndBrain/memory"
if [ -L Claude-Memory ]; then
  echo "Symlink exists — preserving"
elif [ -e Claude-Memory ]; then
  echo "ERROR: Claude-Memory exists and is not a symlink — abort"
  exit 1
else
  ln -s "$TARGET" Claude-Memory
  git add Claude-Memory
  git commit -m "phase-D-1: add Claude-Memory symlink"
fi
```

### D2. Six root sidecars

Create only if missing: `AGENTS.md`, `CLAUDE.md`, `CRITICAL_FACTS.md`, `SOUL.md`, `index.md`, `log.md`. Use `vault-template/` as the stencil.

### D3. CLAUDE.md append-only patch

Never overwrite `CLAUDE.md`. Append a marker-bounded block so the installer can re-apply without duplicating:

```bash
if ! grep -q '<!-- mogging:start -->' CLAUDE.md; then
cat >> CLAUDE.md <<'EOF'

<!-- mogging:start -->
## Post-Mogging Vault Contract (auto-appended)
See docs/MIGRATION.md + CLAUDE-MD-PATCH.md for the canonical block.
<!-- mogging:end -->
EOF
git commit -am "phase-D-3: append mogging block to CLAUDE.md"
fi
```

Re-running is a no-op because of the marker grep.

---

## Phase E — External systems

### E1. n8n workflow path filters

n8n workflows reference the vault by **GitHub API path**, not local filesystem. Before reactivating W1/W2/W3:

1. Export each workflow JSON.
2. Search for `08-Tasks` and `07-Projects` in the JSON.
3. Replace with `06-Tasks` and `05-Projects`.
4. Re-import and activate.

```bash
grep -l '08-Tasks\|07-Projects' n8n-exports/*.json
```

Zero hits = safe to reactivate.

### E2. Morgen / Obsidian Tasks 🆔 field

IDs are stable — do not regenerate. W1 only mints new IDs for rows missing 🆔.

---

## Validation

Run all of these. Every one should be green before declaring migration complete.

```bash
# 1. Folder list matches the contract
ls -d */ | sort
# expected: 01-Conversations/ 02-Sources/ 03-Concepts/ 04-Index/ 05-Projects/ 06-Tasks/

# 2. Zero references to killed or renamed folder names
grep -rn 'path includes 08-Tasks' 06-Tasks/ && echo FAIL || echo OK
grep -rn 'path includes 07-Projects' 06-Tasks/ && echo FAIL || echo OK
grep -rn '\[\[00-Inbox\]\]\|\[\[01-Fleeting\]\]' . && echo FAIL || echo OK

# 3. Submodule intact
git submodule status | grep 06-Tasks

# 4. Symlink present and resolves
readlink Claude-Memory && test -d Claude-Memory/ && echo OK

# 5. Six sidecars present
for f in AGENTS.md CLAUDE.md CRITICAL_FACTS.md SOUL.md index.md log.md; do
  test -f "$f" && echo "OK $f" || echo "MISSING $f"
done

# 6. CLAUDE.md marker block present exactly once
grep -c '<!-- mogging:start -->' CLAUDE.md
# expected: 1
```

---

## Rollback matrix

| Scope | Command |
|---|---|
| Last step only | `git reset --hard HEAD~1` |
| Last N steps | `git reset --hard HEAD~N` |
| Full rollback to pre-migration | `git reset --hard v0-pre-migration` |
| Tarball (git corrupted) | `tar xzf ~/Desktop/2ndBrain-backup-*.tar.gz -C /tmp/restore` |

Phase boundaries are natural checkpoints. If Phase C surfaces 200+ broken wikilinks, reset to end of Phase B and fix in a branch before proceeding.

---

## References

- Short version: root [`MIGRATION.md`](../MIGRATION.md)
- Vault contract: `CLAUDE.md` mogging block, or [`docs/SECURITY.md`](SECURITY.md) for install trust
- Attribution for prior art: [`docs/CREDITS.md`](CREDITS.md)
- Placeholder redaction convention: [`docs/placeholder-names.md`](placeholder-names.md)
