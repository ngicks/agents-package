---
name: ngcommit
description: "commit message convention (emoji prefix). Use whenever running `git commit`, amending a commit, or writing a commit message — even if the user does not mention any message format."
---

# ngcommit

Commit messages follow the repository's own convention document,
`doc/COMMIT_CONVENTION.md`. This skill finds that document, creates it from
the bundled default when it is missing, updates it when the bundled default
moved on, and applies it.

Two files live in the worktree:

- `doc/COMMIT_CONVENTION.md`: the live convention. The project may edit it.
- `doc/COMMIT_CONVENTION_ORG.md`: an untouched copy of the bundled default
  at the time it was copied. Never edit it by hand. It exists so the diff
  against the live file shows what the project changed, and so an updated
  bundled default can be merged in without losing those changes.

## Find the convention

Before writing any commit message, read `doc/COMMIT_CONVENTION.md` relative
to the worktree root (`git rev-parse --show-toplevel`).

- If it exists, it is the authority. Follow it even where it differs from
  the bundled default below; do not "fix" it toward the default.
- If it does not exist, create it first (next section), then follow it.
- If it exists, check for an update (section after next) before applying.
- Read it once per session; re-read only if it changed.

## Create it when missing

Copy `COMMIT_CONVENTION.md`, bundled in this skill's directory, to two
places in the worktree:

- `doc/COMMIT_CONVENTION.md`, the live copy that gets the Scopes table
  filled below.
- `doc/COMMIT_CONVENTION_ORG.md`, a byte-for-byte copy of the bundled
  file. Leave it exactly as copied; do not fill its Scopes table.

Then, in the live copy only:

- Fill the **Scopes** table. It is the only part of the copy that is
  project-specific, and the bundled default only carries placeholder rows.
  - Take candidates from the tree: top-level modules, packages, skill
    directories, and any directory that gets its own commits.
  - Take candidates from history: `git log --format=%s`, scopes inside
    the parentheses. Keep the ones that still match the tree.
  - One row per scope, named exactly as in the tree. Group small or
    rarely-touched directories under one scope.
- Commit both documents on their own, before the commit the user asked
  for, as `📝: add commit convention`. Keeping it separate keeps the
  requested commit focused.
- Tell the user the documents were added and where, and show the scope
  rows so they can correct them.
- Beyond filling the Scopes table, do not edit the copy to fit the change
  at hand. Adjusting a project's convention is the user's decision.

The document must keep at least three tables: the emoji prefix table, the
scope rules table, and the scopes table. A project may add rows, tighten
wording, or add sections, but those three tables are what the rest of this
skill relies on.

## Update it when the bundled default changed

The skill may ship a newer `COMMIT_CONVENTION.md` than the one the project
copied. `doc/COMMIT_CONVENTION_ORG.md` records which version was copied,
so the project's own edits can be told apart from the update.

- Compare the bundled file with `doc/COMMIT_CONVENTION_ORG.md`
  (`diff -q`). If they are identical, there is nothing to update.
- If `doc/COMMIT_CONVENTION_ORG.md` is missing but the live file exists,
  create it from the bundled file and commit it as
  `📝: add commit convention origin`. The project's edits cannot be
  separated from the update this time, so do not touch the live file.
- Otherwise apply the update as a three-way merge, with the old origin as
  the base, the live file as ours, and the bundled file as theirs:

  ```sh
  git merge-file doc/COMMIT_CONVENTION.md doc/COMMIT_CONVENTION_ORG.md <bundled COMMIT_CONVENTION.md>
  ```

  - The project's edits, including the filled Scopes table, survive; only
    the parts the project left untouched pick up the new wording.
  - If the merge leaves conflict markers, resolve them in favor of the
    project's edits and tell the user which hunks conflicted.
- Replace `doc/COMMIT_CONVENTION_ORG.md` with the bundled file, so the next
  update diffs against the right base.
- Commit both files on their own, before the commit the user asked for,
  as `📝: update commit convention`, and tell the user what changed.

## Apply it

Read the tables, then write the subject as `<emoji>(<scope>): description`:

- Pick exactly one emoji whose row matches the primary intent of the change.
- Pick the scope from the scopes table: use the row whose directory the
  change touches. Then apply the scope rules table for multiple scopes,
  cross-cutting changes, and when to omit the parentheses.
- If no row covers the change, do not invent a scope. Add a row to the
  scopes table in its own 📝 commit before the requested commit, and tell
  the user which row was added.
- Keep the description short, lowercase, imperative, no trailing period.
- Add a body only when the "why" is not obvious from the subject.
- When a change mixes intents, prefer one commit per intent.

## Default convention

The bundled `COMMIT_CONVENTION.md` is the default that gets copied. In
short: one prefix emoji from a fixed table (✨ feature, 🐛 fix, 🧹 refactor,
📝 docs, 📦 move / bump, 🔥 remove, ✅ tests, 👷 build / CI, and a few
more), a scope taken from the project's own scopes table, and an imperative
lowercase description. The scopes table is the one part the default leaves
for the project to fill. Read the file itself for the full tables and
examples; do not work from this summary.
