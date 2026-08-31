# Issue backlog — layout, tags, folding and closing

Detail for ngplan's **Fold the ledger into the issue backlog** section: the
durable backlog under `./doc/plan/issue/` that HANDOFF.md entries fold into.
Read this at the fold moment — implementation done, user has reviewed it —
and whenever opening, searching, or closing backlog items.

## Issue backlog layout

The backlog is one item per file, with a derived catalog on top.

- `doc/plan/issue/open/<kebab-case-slug>.md` — one open item per file; these
  files are the authoritative backlog.
- `doc/plan/issue/closed/<kebab-case-slug>.md` — closed items; closing moves
  the file from `open/` verbatim, filename and all.
- `doc/plan/issue/catalog.md` — a derived index, occasionally reconstructed
  from the open items: one entry per item with its title, file path, and
  tags. Regenerate it wholesale after any fold or close; never hand-edit
  item content there, and when it disagrees with `open/`, `open/` wins —
  the catalog is merely stale.
- Every item file — open and closed alike — starts with YAML frontmatter
  carrying a `tags` field: merely a string, a space-separated topic list.

      ---
      tags: cli config planning
      ---

      # <item title>

      <item body>

## Searching the backlog by frontmatter

Search item frontmatter with `scripts/issue-search.sh`, bundled in this
skill's directory.

- `issue-search.sh <pattern> [path ...]` wraps `rg` so that only each
  `*.md` file's leading frontmatter block is searched, never item bodies;
  the path defaults to `doc/plan/issue`.
- It needs `rg` on PATH and must stay executable — `rg --pre` re-invokes
  the script itself per file.
- Run it before folding to find existing items on the same topics — extend
  or cross-reference a matching item rather than duplicating it.

## Folding and closing mechanics

- Timing — this happens strictly after the implementation is done **and** the
  user has followed up on it. Never bundle the fold into the same turn as the
  completion report: report the finished work, wait for the user's review and
  approval of the implementation, and only then offer the fold.
- Ask which entries to fold with `AskUserQuestion` (`multiSelect: true`), one
  option per HANDOFF.md entry (topic). At most ~4 options per round; go in
  rounds for a longer ledger. The built-in "Other" choice is how the user
  answers "all of them" or gives a custom instruction. A single-entry
  ledger gets a fold-or-drop question for that entry instead, since the
  tool needs at least two options. Fall back to plain chat when the tool
  is unavailable.
- Create `doc/plan/issue/open/` (and `doc/plan/issue/` itself) on first use;
  write each selected entry as its own `open/<kebab-case-slug>.md` with the
  frontmatter `tags` line, choosing tags from the item's topics. Existing
  item files are never rewritten — the only other legal mutation is closing
  one (below).
- The backlog outlives the plan directory, so rewrite each folded item to
  stand alone: real paths and symbols, the reasoning in plain words, and no
  plan paths, decision IDs like `D15`, or plan step numbers.
- Closing an item — when the user says an open item is resolved or dropped,
  move its file from `open/` to `closed/` verbatim, frontmatter included.
  Closing happens only on the user's say-so, never because you judge the
  work done.
- After any fold or close, reconstruct `catalog.md` from what `open/` now
  holds.
- Entries the user leaves unselected stay in HANDOFF.md and disappear with
  the plan directory — that is the user's decision to drop them; never fold
  them silently.
- Tell the user what was folded and where.
