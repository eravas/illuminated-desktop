#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
if [[ $# == 0 ]]; then set -- bash; fi
docker run --rm --init --network none --shm-size=256m -w /project \
  -v "$PWD:/project" illuminated-dev "$@"
