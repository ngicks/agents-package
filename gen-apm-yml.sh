#!/usr/bin/env bash

pushd $(dirname $0) > /dev/null 2>&1

moon run ./.tool/cmd/main -- gen-apm-yml "$@"

popd > /dev/null 2>&1
