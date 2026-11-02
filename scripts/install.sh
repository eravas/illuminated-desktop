#!/usr/bin/env bash
# One-step install from a source checkout; arguments go to `illuminated install`.
#   bash scripts/install.sh                 # detect compositor, ask before editing its config
#   bash scripts/install.sh --compositor mango --yes
set -euo pipefail
exec python3 "$(dirname -- "${BASH_SOURCE[0]}")/illuminated" install "$@"
