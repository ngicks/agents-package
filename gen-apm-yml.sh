#!/usr/bin/env bash

pushd $(dirname $0) > /dev/null 2>&1

moon run ./.tool/cmd/main -- gen-apm-yml --exclude '**gorimpots' --exclude '**nix-*' --exclude '**nggoal' "$@"

popd > /dev/null 2>&1
