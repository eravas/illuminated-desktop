#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
bash -n scripts/install.sh scripts/uninstall.sh
python3 - <<'PY'
import ast,pathlib
for path in [*pathlib.Path('tests').rglob('*.py'), *pathlib.Path('lib').rglob('*.py'), pathlib.Path('scripts/illuminated'), pathlib.Path('quickshell/greeter/sessions.py')]:
    ast.parse(path.read_text(), filename=str(path))
PY
python3 scripts/illuminated apply --check >/dev/null  # packaged defaults must validate
node --test tests/*.test.cjs
python3 -m unittest discover -s tests -v
lint=${QMLLINT:-}
if [[ -z $lint ]]; then
 for candidate in /usr/lib/qt6/bin/qmllint /usr/lib/qt6/qmllint /usr/lib64/qt6/bin/qmllint; do
  if [[ -x $candidate ]]; then lint=$candidate; break; fi
 done
fi
if [[ -z $lint ]]; then lint=$(command -v qmllint6 || true); fi
# qmllint reports Quickshell type-info gaps it cannot resolve, so by default its
# warnings are shown but do not fail validation. STRICT_LINT=1 makes them fatal.
if [[ -n $lint ]]; then
 status=0
 # Quickshell resolves `import qs.skin` (skins) itself; qmllint needs a qs/ folder for it.
 imports=$(mktemp -d); trap 'rm -rf "$imports"' EXIT
 mkdir "$imports/qs"; ln -s "$PWD/quickshell/skin" "$imports/qs/skin"
 report=$(mktemp)
 while IFS= read -r -d '' file; do
   args=(--max-warnings 0 -I /usr/lib/qt6/qml -I "$imports")
   directory=${file%/*}
   if [[ -f $directory/qmldir ]]; then args+=(-i "$directory/qmldir"); fi
   "$lint" "${args[@]}" "$file" >> "$report" 2>&1 || status=1
 done < <(find quickshell -name '*.qml' -not -path 'quickshell/skins/example/*' -print0)
 # The example skin as the shell sees it: laid over the default skin (illuminated apply).
 mkdir "$imports/example"; cp quickshell/skins/default/*.qml "$imports/example/"; cp -f quickshell/skins/example/*.qml "$imports/example/"
 for file in quickshell/skins/example/*.qml; do
   "$lint" --max-warnings 0 -I /usr/lib/qt6/qml -I "$imports" "$imports/example/${file##*/}" 2>&1 | sed "s#$imports/example/#quickshell/skins/example/#" >> "$report" || status=1
 done
 cat "$report"
 # Always fatal: an unknown type or a missing import fails to load at runtime. (This replaced the
 # hand-written structure test; qmllint finds both classes.)
 if grep -q '\[import\]' "$report"; then
  printf 'qmllint: unknown type or missing import (fatal):\n'; grep '\[import\]' "$report"; exit 1
 fi
 if [[ $status != 0 && ${STRICT_LINT:-0} != 1 ]]; then
  printf 'qmllint reported warnings (not fatal; set STRICT_LINT=1 to enforce).\n'
  exit 0
 fi
 exit "$status"
else
 printf 'NOT RUN: qmllint unavailable; QML syntax/types remain unverified.\n'
fi
