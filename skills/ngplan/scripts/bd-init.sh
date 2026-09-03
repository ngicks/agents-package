#!/bin/sh
# Idempotent beads (bd) initialization for a repository that may be
# checked out as several git worktrees.
#
# - No-op (exit 0) when bd is already initialized.
# - Derives the issue prefix from the repository root directory, never from
#   the worktree directory, so every worktree agrees on the same prefix.
#   Override with BEADS_PREFIX=<prefix>.
# - Writes nothing into the worktree: no AGENTS.md, no git hooks, no push.
set -eu

if ! command -v bd >/dev/null 2>&1; then
  echo "bd-init: bd is not installed; skipping beads initialization" >&2
  exit 0
fi

if bd info -q >/dev/null 2>&1; then
  exit 0
fi

if [ -n "${BEADS_PREFIX:-}" ]; then
  prefix=$BEADS_PREFIX
else
  # The git common dir is `<root>/.git` for a normal checkout and
  # `<root>/.bare` (or similar) for a bare-repo + sibling-worktrees layout.
  # Its parent is the repository root in both cases.
  common=$(git rev-parse --git-common-dir)
  common=$(cd "$common" && pwd -P)
  root=$(dirname "$common")
  prefix=$(basename "$root" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//; s/-*$//')
fi

if [ -z "$prefix" ]; then
  echo "bd-init: could not derive a prefix; set BEADS_PREFIX" >&2
  exit 1
fi

exec bd init -p "$prefix" --init-if-missing --skip-agents --skip-hooks --non-interactive -q
