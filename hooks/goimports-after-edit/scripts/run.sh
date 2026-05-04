#!/usr/bin/env bash
set -euo pipefail

file=$(
	sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
		head -n 1
)

case "$file" in
*.go) ;;
*) exit 0 ;;
esac

test -f go.mod || exit 0
command -v goimports >/dev/null 2>&1 || exit 0

goimports -w "$file"
