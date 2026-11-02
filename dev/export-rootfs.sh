#!/usr/bin/env bash
# Optional fallback for a Docker VFS host with insufficient room for containers.
set -euo pipefail
cd "$(dirname "$0")/.."
ca=${CODEX_PROXY_CERT:-/etc/ssl/certs/ca-certificates.crt}
set -o pipefail
docker build --secret "id=proxy_ca,src=$ca" -f dev/Dockerfile \
 --output type=tar,dest=- . | gzip -1 > "${1:-/workspace/illuminated-rootfs.tar.gz}"
