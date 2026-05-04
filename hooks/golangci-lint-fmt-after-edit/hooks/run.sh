#!/usr/bin/env bash
set -euo pipefail

file=$(jq -r '.tool_input.file_path // empty')

case "$file" in
*.go) ;;
*) exit 0 ;;
esac

test -f go.mod || exit 0
command -v golangci-lint >/dev/null 2>&1 || exit 0

golangci-lint fmt "$file"
