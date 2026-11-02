#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ca=${CODEX_PROXY_CERT:-/etc/ssl/certs/ca-certificates.crt}
docker build --secret "id=proxy_ca,src=$ca" -f dev/Dockerfile -t illuminated-dev .
