#!/usr/bin/env bash
# Removes everything install added; keeps ~/.config/illuminated/config.toml unless --purge.
set -euo pipefail
exec python3 "$(dirname -- "${BASH_SOURCE[0]}")/illuminated" uninstall "$@"
