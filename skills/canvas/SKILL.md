---
name: canvas
description: Generate and maintain Obsidian Canvas files from vault queries. Adds images, text, PDFs, pinned notes, and labeled zones with deterministic IDs and strict JSON Canvas 1.0 validation. Central Map.canvas uses a Fibonacci spiral layout so the vault has a single visual index. Ported from AgriciDaniel.
allowed-tools: Read, Write, Glob, Grep
---

# /canvas

Scripted authoring for Obsidian Canvas files. The canvas format is stable JSON (Canvas 1.0) — this skill treats canvases as a view layer over the vault, never mutating source notes. Every node gets a collision-proof ID, every write re-reads the canvas first to prevent dupes, and the central `04-Index/Map.canvas` gets a deterministic Fibonacci-spiral layout so the graph stays legible as it grows.

## Invocation

```
/canvas [subcommand] [args]
```

Running bare `/canvas` reports status: total canvases, per-canvas node counts, zones, and any open instruction cards (text nodes with `TODO:` prefix).

## Subcommands

### /canvas new `<name>`

Create `04-Index/canvases/{name}.canvas` with an empty `{ "nodes": [], "edges": [] }` skeleton. Reject if the file already exists — the caller must delete or pick a new name. Name is slugified (kebab-case, ASCII-only).

### /canvas add image `<path-or-url>`

- If `<path>` is an `https://` URL, download to `06-Assets/canvas-imports/{slug}-{ts}.{ext}` (scheme whitelist, 5 MB cap, 30 s timeout).
- If `<path>` is a local vault-relative path, verify it resolves inside the vault (reject directory traversal) and reference it directly — no copy needed.
- Read image dimensions; size the node aspect-ratio-aware, capped at 600 × 800. Small images (<200 px side) get upscaled to 300 px minimum so they're readable.
- Auto-layout: append at `max_x + 40` of the target zone (default: active canvas root).

### /canvas add text `<content>`

Create a `type: "text"` node, 300 × 120, color `4` (green). Content is markdown — wikilinks render, so `[[concept]]` lights up the graph. Long content wraps to 300 × (120 + 40 per extra line), capped at 300 × 400; longer content should be a real note, not a canvas card.

### /canvas add pdf `<path>`

Create a `type: "file"` node pointing at the vault-relative PDF path. Size 400 × 520 (rendered preview aspect). PDF must live inside the vault — reject absolute external paths.

### /canvas add note `<page>`

Pin a wiki page as a `type: "file"` node. `<page>` is resolved via Glob against the whole vault (case-insensitive, matches on filename without extension). If multiple matches, emit the list and ask the caller to disambiguate — never guess. Size 300 × 100.

### /canvas zone `<name>` `[color]`

Create a `type: "group"` labeled group node, 1000 × 400, default color `3`. Color accepts `1`-`6` (Obsidian palette) or a hex string (stored verbatim; Obsidian renders arbitrary hex). Subsequent `/canvas add *` calls attach to the most-recently-created zone until a new zone is created or `--zone <name>` is passed explicitly.

### /canvas list

Glob `**/*.canvas` across the vault. For each file, read and report: node count by type (`file`, `text`, `link`, `group`), edge count, last-modified timestamp. Sort by mtime descending.

## Output Format

All writes emit valid JSON Canvas 1.0:

```json
{
  "nodes": [
    { "id": "text-note-1712345678", "type": "text", "x": 0, "y": 0, "width": 300, "height": 120, "text": "...", "color": "4" },
    { "id": "file-concept-1712345679", "type": "file", "x": 340, "y": 0, "width": 300, "height": 100, "file": "03-Concepts/concept.md" },
    { "id": "group-zone-1712345680", "type": "group", "x": -20, "y": -40, "width": 1000, "height": 400, "label": "Research", "color": "3" }
  ],
  "edges": [
    { "id": "edge-1712345681", "fromNode": "text-note-1712345678", "toNode": "file-concept-1712345679" }
  ]
}
```

Validation runs before every write:

- Node `type` must be one of `file`, `text`, `link`, `group`.
- All IDs must be unique within the canvas.
- Numeric fields (`x`, `y`, `width`, `height`) must be finite.
- `file` nodes must reference a path that resolves inside the vault.
- `link` nodes must carry an `https://` URL.
- Rejecting a canvas aborts the write — never emit malformed JSON.

## ID Convention

Every node ID follows `{type}-{content-slug}-{unix-ts}` where `{unix-ts}` is exactly 10 digits (seconds-since-epoch, not ms). Example: `text-card-backprop-intuition-1712345678`.

For batch operations that complete inside the same second, append `-2`, `-3`, … to the second and later colliding IDs. Before appending, re-read the canvas and collect existing IDs — never trust an in-memory set across separate invocations.

Slug rules: lowercase, ASCII-only, hyphen-separated, first 24 chars of the content after stripping stopwords. Text nodes with no meaningful words fall back to `note`, `card`, or `scratch`.

## Auto-Positioning

New cards land at `max_x_in_zone + 40, y_of_zone_top`. When the running x exceeds `zone.x + zone.width - card.width`, wrap to a new row: reset x to `zone.x + 20`, advance y by the tallest card in the just-completed row plus 40.

If no zone is active, use the canvas root with an implicit bounding box computed from existing nodes. An empty canvas starts at `(0, 0)`.

Overflow protection: if a zone fills past 8 rows without an explicit resize, emit a warning and ask the caller whether to auto-expand the zone height or create a sibling zone.

## Central Hub: 04-Index/Map.canvas

`Map.canvas` is the single-entry visual index for the vault. Layout is a Fibonacci spiral using the golden angle `137.5°` so nodes never align into readable rings (visually cleaner, scales without collision up to ~500 nodes).

- Central node: `04-Index/Index.md`, size 400 × 200, positioned at origin.
- Radiating nodes: MOC files (`MOC-*.md`, `Home-Index`, `Projects-Index`, `Poetry-Index`, `Tech-Index` equivalents). Each sits at radius `r = base + step * sqrt(i)` and angle `theta = i * 137.5° (rad)` for node index `i`.
- Edges: Index → every MOC, undirected style (Obsidian ignores direction visually but stores it).
- Rebuild is idempotent: running `/canvas map-rebuild` reads the current vault MOC set, diffs against existing Map.canvas nodes, and only adds/removes — existing nodes keep their IDs and computed positions.

Constants: `base = 260`, `step = 220`. Tuning these should be discussed with the vault owner before merging — they set the visual density of the hub.

## Safety Rails

- **Never mutate source notes.** This skill is view-layer only. `/canvas add note foo` pins a reference; it does not edit `foo.md`.
- **Read-before-write every canvas.** IDs must be checked against the on-disk state, not an in-memory guess.
- **Reject path traversal.** `../` sequences and absolute paths outside the vault fail validation.
- **URL downloads** follow the same scheme whitelist and SSRF block list as `/autoresearch`. Images over 5 MB are rejected rather than truncated.
- **Atomic writes.** Write to `{path}.tmp`, fsync, then rename. A crashed write never leaves a half-valid canvas on disk.
- **Backups.** Before any `map-rebuild` or bulk operation (>10 node ops), copy the target canvas to `04-Index/canvases/.backups/{name}-{iso-date}.canvas`.

## Status Report (`/canvas`)

Bare `/canvas` returns a compact report, per canvas file:

```
04-Index/Map.canvas          43 nodes (38 file, 3 group, 2 text) · 57 edges · 0 TODOs
04-Index/canvases/research.canvas  12 nodes (8 file, 4 text) · 6 edges · 2 TODOs
```

"TODOs" = text nodes whose content starts with `TODO:`, `FIXME:`, or `?:`. Useful for spotting stale scratch cards the next time you open the canvas.

## Failure Modes

- **Ambiguous note match** → emit candidate list, abort. Never pin a guess.
- **ID collision after 5 suffix attempts** → abort with the existing IDs in the error; this indicates the timestamp source is broken.
- **Invalid JSON Canvas** → abort, leave the original file untouched, dump the rejected payload to `04-Index/canvases/.rejected/{ts}.json` for debugging.
- **Vault path outside root** → abort with the attempted path in the error.
- **URL download fails SSRF or size check** → abort that add, continue the rest of a batch if any.

## Example

```
/canvas new research-scratch
/canvas zone "Round 1 sources" 3
/canvas add note JSCalendar
/canvas add note RFC-8984
/canvas add text "Both specs agree on floating datetime semantics; Morgen API differs."
/canvas zone "Open questions" 5
/canvas add text "TODO: check Motion API floating datetime handling"
/canvas
```

Result: one new canvas at `04-Index/canvases/research-scratch.canvas` with two zones, two pinned notes, two text cards, and a reported 1 TODO in the status line.

The skill stays tight: canvases are cheap, deterministic, and never lie about what's on disk.
