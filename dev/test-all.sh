#!/usr/bin/env bash
# Inside the Arch runtime. Every integration section uses a fresh private session.
set -euo pipefail
cd /project
mkdir -p artifacts/development artifacts/portable artifacts/v3
for suite in foundation artifacts smoke audio skin reload compositor greeter single-config session-ui; do
 printf 'NOT RUN\n' > "artifacts/development/$suite.exit"
done
set +e
# Non-strict: qmllint warnings are shown, not fatal (Quickshell type metadata gaps). STRICT_LINT=1 makes them fatal.
bash scripts/validate.sh > artifacts/development/lint.txt 2>&1
lint_status=$?
set -e
printf '%s\n' "$lint_status" > artifacts/development/lint.exit
for suite in foundation artifacts smoke audio skin reload compositor greeter single-config session-ui; do
 case "$suite" in
  foundation) command=(python tests/runtime/run.py) ;;
  artifacts) command=(python tests/runtime/artifacts.py) ;;
  compositor) command=(python tests/runtime/compositor.py) ;;
  greeter) command=(python tests/runtime/greeter-protocol.py) ;;
  reload) command=(python tests/runtime/reload.py) ;;
  smoke) command=(python tests/runtime/smoke.py) ;;
  single-config) command=(python tests/runtime/single-config.py) ;;
  session-ui) command=(python tests/runtime/session-ui.py) ;;
  audio) command=(timeout 55s bash dev/audio-session.sh python tests/runtime/audio.py) ;;
  skin) command=(timeout 200s bash dev/audio-session.sh python tests/runtime/skin.py) ;;
 esac
 set +e
 dbus-run-session -- bash dev/headless.sh "${command[@]}" > "artifacts/development/$suite-result.txt" 2>&1
 suite_status=$?
 set -e
 printf '%s\n' "$suite_status" > "artifacts/development/$suite.exit"
 if [[ $suite_status != 0 ]]; then printf 'FAIL: %s (exit %s)\n' "$suite" "$suite_status"; exit "$suite_status"; fi
 printf 'PASS: %s\n' "$suite"
done
printf 'Runtime suites passed. Strict lint exit: %s (see full lint.txt).\n' "$lint_status"
