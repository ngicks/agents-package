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
command -v golangci-lint >/dev/null 2>&1 || exit 0

golangci-lint fmt "$file"
