#!/usr/bin/env bash

set -euo pipefail

sources=(ngicks/agents-package/bundle/myenv)
targets="claude,codex,opencode"

if ! command -v apm >/dev/null 2>&1; then
  echo "apm not found; install it first, e.g. 'mise use -g pipx:apm-cli' or 'pipx install apm-cli'" >&2
  exit 1
fi

if [ -f "$HOME/.apm/apm.yml" ]; then
  apm update -g --yes -t "$targets"
fi

apm install -g -t "$targets" --trust-bin --trust-transitive-mcp "${sources[@]}"

# mcp entries in apm.yml go into ${CLAUDE_CONFIG_DIR}/.claude.json
#
# So after installation, there would be a dup betewen
# `.claude.json` and `skills/crabswarm-mcp-shared`
#
# There's no stable cli command which turns off mcp rather than 
# removing it.
if command -v claude >/dev/null 2>&1; then
  claude mcp remove crabswarm-mcp-shared --scope user || true
fi
