#!/usr/bin/env bash

set -euo pipefail

sources=(ngicks/agents-package/bundle/myenv)
targets="claude,codex,opencode"

if ! command -v apm >/dev/null 2>&1; then
  echo "apm not found; install it first, e.g. 'mise use -g pipx:apm-cli' or 'pipx install apm-cli'" >&2
  exit 1
fi

# The bundle lists mods that ship bin/ executables and transitive packages
# that define their own MCP servers. apm skips both in non-interactive
# shells unless told to trust them.
apm install -g -t "$targets" --trust-bin --trust-transitive-mcp "${sources[@]}"

if [ "${MYENV_UPDATE:-0}" = "1" ]; then
  apm update -g --yes
fi
