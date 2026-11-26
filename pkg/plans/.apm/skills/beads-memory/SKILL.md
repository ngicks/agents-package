---
name: beads-memory
description: Record, recall, update, and remove persistent memories in the repository's beads (`bd`) database with `bd remember`, `bd memories`, `bd recall`, and `bd forget`. Use when the user says "remember this", when a durable project fact, convention, or corrected approach should survive the session, or to look up what earlier sessions recorded before starting work.
---

# beads-memory

Keep memories in the repository's beads (`bd`) database.
A memory is a short key and a text value.
The database is shared by every git worktree and travels with `bd dolt push`, so a memory reaches other machines and other agents.

## Before any command

- Pass `--actor <actor>` on every `bd` invocation, reads included.
  - The actor is `<agent>/<model>`: the agent harness in lowercase (`claude`, `codex`, `opencode`)
    and the model id it is running, e.g. `claude/claude-fable-5-1`.
  - Drop the `/<model>` part only when the model is genuinely unknown.
  - Never use the user's name.
- Check that the database exists with `bd --actor <actor> info -q`. Exit status 0 means beads is initialized.
- This skill does not initialize beads. The `beads-init` skill does.
  When the check fails, load the `beads-init` skill, follow it, then continue. Never run raw `bd init`.
- `bd` missing is blocking. Tell the user and stop instead of writing the memory into a file.
- Never run `bd dolt push`; syncing off the machine is the user's job.

## Recall

Nothing loads memories on its own. Read them at the start of work that may depend on them.

```bash
bd --actor <actor> memories                 # every memory, key and value
bd --actor <actor> memories "<words>"       # search by keyword
bd --actor <actor> recall <key>             # one memory in full
bd --actor <actor> prime --memories-only    # all memories as one markdown block
```

- `memories "<words>"` exits 0 with no match; an empty result means nothing is recorded.
- `recall <key>` exits 1 when the key does not exist.

## Record

```bash
bd --actor <actor> remember "<memory text>" --key <key>
```

- Always pass `--key`. Without it bd derives a key from the text, which is hard to find and update later.
- Search first with `bd --actor <actor> memories "<words>"`.
  - `remember` with an existing key replaces that memory in place and prints `Updated [<key>]`.
  - A new key prints `Remembered [<key>]`.
  - To extend a memory, `recall` it, then `remember` the full merged text under the same key.
- The text is a shell argument. Multi-line text works inside the quotes; there is no stdin or file input.
- Never pass a bare word as the only argument: `bd remember <key>` recalls that key instead of storing.
- Never use the key `schema_version`; `bd memories --json` drops it.

### What to record

Record what changes how a future session should act and stays true across sessions.

- Record: project conventions, an approach the user corrected, non-obvious environment facts, pointers to where things live.
- Do not record: task progress, plans, decisions that belong to one plan, or anything a `git log` or the code already shows.
- Never record secrets, credentials, or personal data.

### How to write it

- Key: lowercase words joined by `-`, topic first, e.g. `test-race-flag`, `dolt-remote-layout`.
- Text: the fact or rule in one sentence, then the reason, then the scope when it is narrower than the repository.
- One memory per fact. Split a memory that covers two topics.
- Write it to stand alone: real paths and command names, no reference to the session it came from.

## Remove

```bash
bd --actor <actor> forget <key>
```

- Remove a memory when it is wrong or no longer holds. Correct a still-useful one with `remember` under the same key.
- `forget` exits 1 when the key does not exist.
- Tell the user whenever you record, replace, or remove a memory, naming the key.
