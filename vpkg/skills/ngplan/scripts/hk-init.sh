#!/bin/sh
# Idempotent hk wiring for a repository whose plan lives in beads.
#
# - No-op (exit 0) when the worktree is already wired and the hooks are
#   installed; safe to run on every invocation.
# - Copies reference/beads.hk.pkl (next to this script) to `.hk/beads.pkl`
#   at the worktree root whenever the two differ, so a skill update or a
#   stale hk pin is picked up by simply running the script again.
# - Pins the hk package version in that copy: the version `hk.pkl` already
#   amends, else the one the existing copy pins, else the installed hk. A
#   pin whose major differs from the installed hk is replaced, because the
#   Pkl schema is not compatible across majors (a 1.x copy does not
#   evaluate under hk 2.0).
# - Makes `hk.pkl` amend `.hk/beads.pkl`: creates a one-line `hk.pkl` when
#   there is none, and rewrites an `amends "package://…/hk@…#/Config.pkl"`
#   line when the project already has one. Pkl's amend chain merges the
#   project's `hooks` and `steps` with the beads hooks, so nothing else in
#   `hk.pkl` changes. Any other `amends` is left alone with instructions
#   printed and exit 1.
# - Runs `hk install`, which on Git 2.54+ writes config-based hooks into
#   the shared repository config (one install covers every worktree) and
#   which hk skips by itself when hooks are installed globally.
# - Exits 0 without doing anything when hk is not installed; commits then
#   simply carry no `Executed-By` trailer.
#
# `hk.pkl` and `.hk/beads.pkl` are meant to be committed: a worktree that
# does not have them runs no hooks.
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
src="$here/../reference/beads.hk.pkl"

if ! command -v hk >/dev/null 2>&1; then
  echo "hk-init: hk is not installed; skipping hook setup (agent commits get no Executed-By trailer)" >&2
  exit 0
fi

top=$(git rev-parse --show-toplevel)
cd "$top"

pkg_prefix='package://github.com/jdx/hk/releases/download/v'
# Prints the version pinned by an `amends "package://…/vX/hk@X#/Config.pkl"` line.
pinned_version() {
  [ -f "$1" ] || return 0
  sed -n 's#^amends "'"$pkg_prefix"'\([^/"]*\)/hk@[^"#]*\#/Config.pkl"[[:space:]]*$#\1#p' "$1" | head -n 1
}

installed=$(hk --version | sed 's/^hk[[:space:]]*//; s/[[:space:]].*//')
version=$(pinned_version hk.pkl)
[ -n "$version" ] || version=$(pinned_version .hk/beads.pkl)
if [ -z "$version" ] || [ "${version%%.*}" != "${installed%%.*}" ]; then
  version=$installed
fi

changed=

# 1. The beads config copy, pinned to $version.
mkdir -p .hk
tmp=.hk/beads.pkl.tmp.$$
trap 'rm -f "$tmp"' EXIT
sed 's#^amends "'"$pkg_prefix"'[^/"]*/hk@[^"#]*\#/Config.pkl"#amends "'"$pkg_prefix$version"'/hk@'"$version"'\#/Config.pkl"#' "$src" > "$tmp"
if ! cmp -s "$tmp" .hk/beads.pkl 2>/dev/null; then
  mv "$tmp" .hk/beads.pkl
  changed="$changed .hk/beads.pkl"
fi

# 2. hk.pkl amends the copy.
if [ ! -f hk.pkl ]; then
  printf 'amends ".hk/beads.pkl"\n' > hk.pkl
  changed="$changed hk.pkl"
elif grep -q '\.hk/beads\.pkl' hk.pkl; then
  : # already wired
elif [ -n "$(pinned_version hk.pkl)" ]; then
  sed 's#^amends "'"$pkg_prefix"'[^/"]*/hk@[^"#]*\#/Config.pkl"[[:space:]]*$#amends ".hk/beads.pkl"#' hk.pkl > "$tmp"
  mv "$tmp" hk.pkl
  changed="$changed hk.pkl"
else
  cat >&2 <<EOF
hk-init: hk.pkl does not amend hk's Config.pkl, so it cannot be rewired automatically.
hk-init: wire .hk/beads.pkl in by hand, then rerun this script:
hk-init:   import ".hk/beads.pkl" as beads
hk-init:   hooks = (beads.hooks) { ...existing hooks body... }
EOF
  exit 1
fi

# 3. Git hooks. hk skips this on its own when hooks are installed globally.
hk install -q

if [ -n "$changed" ]; then
  echo "hk-init: wrote$changed; commit them so every worktree runs the hooks" >&2
fi
