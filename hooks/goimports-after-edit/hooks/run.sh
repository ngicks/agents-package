#!/usr/bin/env bash
set -euo pipefail

file=$(jq -r '.tool_input.file_path // empty')

case "$file" in
*.go) ;;
*) exit 0 ;;
esac

test -f go.mod || exit 0
command -v goimports >/dev/null 2>&1 || exit 0

goimports -w "$file"
