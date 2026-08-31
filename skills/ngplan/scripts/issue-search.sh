#!/bin/sh
# issue-search.sh — search only the YAML frontmatter of issue item files.
#
# usage: issue-search.sh <pattern> [path ...]
#   default path: doc/plan/issue
#
# Wraps ripgrep: every *.md file is preprocessed down to its leading
# frontmatter block (the lines between the opening `---` pair), so matches
# never come from item bodies. Files without frontmatter yield nothing.
#
# This script must stay executable — rg re-invokes it per file via --pre.
set -eu

# --pre re-entry: rg runs `$0 <file>` with this variable set; print only
# the frontmatter block.
if [ "${ISSUE_SEARCH_FRONTMATTER_ONLY:-}" = "1" ]; then
  awk 'NR==1 { if ($0 != "---") exit; next } /^---$/ { exit } { print }' "$1"
  exit 0
fi

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <pattern> [path ...]" >&2
  exit 2
fi

pattern=$1
shift
[ "$#" -eq 0 ] && set -- doc/plan/issue

self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
ISSUE_SEARCH_FRONTMATTER_ONLY=1 exec rg --pre "$self" --pre-glob '*.md' -e "$pattern" "$@"
