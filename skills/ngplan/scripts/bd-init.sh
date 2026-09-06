#!/bin/sh
# Idempotent beads (bd) initialization for a repository that may be
# checked out as several git worktrees.
#
# - No-op (exit 0) when bd is already initialized.
# - Creates the database at the repository root (the parent of the git
#   common dir), never in the current worktree, so every worktree shares it.
# - Derives the issue prefix from that same root directory, so every
#   worktree agrees on the prefix. Override with BEADS_PREFIX=<prefix>.
# - Turns off bd's anonymous usage metrics (`bd metrics off`).
# - Writes nothing into the worktree: no AGENTS.md, no git hooks, no push.
# - Mirrors the git `origin` remote as the Dolt remote `origin` (git+https://
#   or git+ssh://), so `bd dolt push` works once the user runs it. This only
#   records the URL; nothing is fetched or pushed.
set -eu

if ! command -v bd >/dev/null 2>&1; then
  echo "bd-init: bd is not installed; skipping beads initialization" >&2
  exit 0
fi

# Opt out of anonymous usage metrics. The setting is machine-global and the
# command is idempotent, so run it before any other bd command on every path.
bd metrics off >/dev/null 2>&1 || true

# Git origin URL -> Dolt remote URL. Prints nothing for forms Dolt cannot use.
dolt_remote_url() {
  case "$1" in
    git+https://*|git+ssh://*) echo "$1" ;;
    https://*) echo "git+$1" ;;
    ssh://*) echo "git+$1" ;;
    *@*:*) # scp-like: user@host:path
      echo "git+ssh://$(echo "$1" | sed 's#:#/#')" ;;
    *) ;;
  esac
}

# Keep the Dolt remote in step with the git origin. `bd dolt remote add` is an
# upsert, so this is idempotent and safe to run on every invocation.
sync_remote() {
  origin=$(git remote get-url origin 2>/dev/null || true)
  [ -n "$origin" ] || return 0
  url=$(dolt_remote_url "$origin")
  [ -n "$url" ] || return 0
  bd dolt remote add origin "$url" -q >/dev/null
}

if bd info -q >/dev/null 2>&1; then
  sync_remote
  exit 0
fi

# The git common dir is `<root>/.git` for a normal checkout and
# `<root>/.bare` (or similar) for a bare-repo + sibling-worktrees layout.
# Its parent is the repository root in both cases. The database is created
# there, not in the current worktree, so you can manipulate it even on bare root.
common=$(git rev-parse --git-common-dir)
common=$(cd "$common" && pwd -P)
root=$(dirname "$common")

if [ -n "${BEADS_PREFIX:-}" ]; then
  prefix=$BEADS_PREFIX
else
  prefix=$(basename "$root" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//; s/-*$//')
fi

if [ -z "$prefix" ]; then
  echo "bd-init: could not derive a prefix; set BEADS_PREFIX" >&2
  exit 1
fi

cd "$root"
bd init -p "$prefix" --init-if-missing --skip-agents --skip-hooks --non-interactive -q
sync_remote
