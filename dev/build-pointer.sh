#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cc -Wall -Wextra -O2 tests/runtime/native/pointer.c tests/runtime/native/pointer-protocol.c \
 $(pkg-config --cflags --libs wayland-client) -o tests/runtime/native/pointer
