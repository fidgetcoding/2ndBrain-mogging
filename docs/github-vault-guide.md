# GitHub + Vault Integration Guide

How to connect your Obsidian vault to your GitHub repos so Claude can look things up in both places. This is the fallback lookup: if something isn't in the vault, Claude checks the matching repo via `gh` CLI.

---

## The concept

Your Obsidian vault is your knowledge base. Your GitHub repos are where the actual code lives. The vault is the brain that connects everything together. When Claude can't find something in the vault, it falls back to checking your GitHub repos.

## Lookup order

1. **Obsidian vault first.** Search `05-Projects/`, `03-Concepts/`, `04-Index/`, etc.
2. **GitHub repos second.** If the vault doesn't have it, check the corresponding GitHub repo via `gh` CLI.

## Connecting projects to repos

Each project folder in `05-Projects/` can map to one or more GitHub repos. Add this to the project's index note (the `05-Projects/<PROJECT>/<PROJECT>.md` file):

```markdown
## GitHub Repos

- [repo-name](https://github.com/your-org/repo-name)
```

`## GitHub Repos` is the documented convention — keep the heading spelled exactly that way so Claude finds the repo URLs when the vault lookup comes up empty. (`/tether` audits a project's **Related** section and the org-hub `## Repos` / `## Owned By` / `## Projects` sections, not this one — see `skills/tether/SKILL.md`.)

## `gh` CLI commands Claude will use

Claude reaches for these when the vault comes up empty:

```bash
# List files in a repo
gh api repos/YOUR-ORG/REPO-NAME/contents/ --jq '.[].name'

# Search code across a repo
gh search code "search term" --repo YOUR-ORG/REPO-NAME

# Read a specific file
gh api repos/YOUR-ORG/REPO-NAME/contents/path/to/file.md --jq '.content' | base64 -d

# Get repo README
gh repo view YOUR-ORG/REPO-NAME
```

## Setting it up

1. Install `gh` (via `brew install gh` on macOS, or the `cli-maxxing` installer if you're running that too).
2. `gh auth login` (public + private repos both work after auth).
3. Tell Claude your GitHub username or organization — Claude runs `gh repo list YOUR-ORG` to see all your repos.
4. For each repo that has a matching project folder in `05-Projects/`, add a `## GitHub Repos` section to that project's index note.

## Day-to-day use

Once connected, you can tell Claude things like:

- "Check the `<ORG-D>` repo for the latest README and update my vault."
- "Pull the spec from the `clocked-hq` repo into my project notes."
- "Search my GitHub repos for anything about authentication and put the hits into `03-Concepts/`."

Claude uses `gh` to grab what it needs and routes the content through the normal write rules (see [PARSING-GUIDE.md](PARSING-GUIDE.md)) — no special case for GitHub-sourced content.

## Requirements

- `gh` CLI installed and authed
- Matching project folder in `05-Projects/` (one per repo, or one project for a cluster of related repos — your call)
- `## GitHub Repos` section added to the project index

That's it. The vault stays the source of truth; the repos stay the source of code; `gh` is the bridge.
