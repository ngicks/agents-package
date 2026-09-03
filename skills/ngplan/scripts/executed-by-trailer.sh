#!/bin/sh
# prepare-commit-msg hook body: stamp `Executed-By: <agent>` on commits made
# by a coding agent, so agent-made commits are distinguishable from human
# ones. Nothing is stamped for a human at a plain shell.
#
# Usage (as a git prepare-commit-msg hook, e.g. via a hook manager such as hk):
#   executed-by-trailer.sh <commit-msg-file> [<source> [<sha>]]
#
# Detection order:
#   1. Nearest ancestor process named claude / codex / opencode wins. This is
#      nesting-aware: an agent launched from inside another agent is the one
#      that actually ran `git commit`.
#   2. Otherwise the environment. Codex is checked first because its sandbox
#      hides the process tree, which is exactly when step 1 finds nothing.
#        CODEX_THREAD_ID -> codex
#        OPENCODE        -> opencode
#        CLAUDECODE      -> claude
#   3. Otherwise no trailer.
#
# Requires only git and POSIX sh; uses /proc when present, `ps` otherwise.
set -eu

msg_file=${1:?commit message file required}
source=${2:-}

# Skip merges and squash messages git generates itself.
case "$source" in merge|squash) exit 0 ;; esac

classify() {
  case "$1" in
    claude|claude-code) echo claude ;;
    codex) echo codex ;;
    opencode) echo opencode ;;
    *) return 1 ;;
  esac
}

parent_of() {
  if [ -r "/proc/$1/stat" ]; then
    awk '{print $4}' "/proc/$1/stat"
  else
    ps -o ppid= -p "$1" 2>/dev/null | tr -d ' '
  fi
}

comm_of() {
  if [ -r "/proc/$1/comm" ]; then
    cat "/proc/$1/comm"
  else
    ps -o comm= -p "$1" 2>/dev/null | sed 's#.*/##'
  fi
}

detect_by_ancestry() {
  pid=$$
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
    name=$(comm_of "$pid" 2>/dev/null || true)
    if agent=$(classify "$name"); then
      echo "$agent"
      return 0
    fi
    pid=$(parent_of "$pid" 2>/dev/null || true)
  done
  return 1
}

detect_by_env() {
  if [ -n "${CODEX_THREAD_ID:-}" ]; then echo codex
  elif [ -n "${OPENCODE:-}" ]; then echo opencode
  elif [ -n "${CLAUDECODE:-}" ]; then echo claude
  else return 1
  fi
}

agent=$(detect_by_ancestry || detect_by_env || true)
[ -n "$agent" ] || exit 0

# Idempotent: git dedups an identical trailer, so amend/reword do not double it.
git interpret-trailers --in-place --if-exists addIfDifferent \
  --trailer "Executed-By: $agent" "$msg_file"
