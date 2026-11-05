#!/usr/bin/env bash
# Run from any directory. FLUTTER_BIN/DART_BIN can select a specific Flutter SDK.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter_bin="${FLUTTER_BIN:-flutter}"
dart_bin="${DART_BIN:-dart}"

if ! command -v "$flutter_bin" >/dev/null || ! command -v "$dart_bin" >/dev/null; then
  echo "Add stable Flutter's bin directory to PATH, or set FLUTTER_BIN and DART_BIN." >&2
  exit 127
fi

"$flutter_bin" --version
"$flutter_bin" pub get --enforce-lockfile "$@"
"$dart_bin" run build_runner build
"$dart_bin" format --output=none --set-exit-if-changed lib test integration_test tool
"$flutter_bin" analyze --no-pub
"$flutter_bin" test --no-pub
bash tool/check_schema.sh
python3 tool/verify_project_config.py
python3 tool/verify_sqlite_schema.py

"$dart_bin" run tool/emit_test_restore_plan.dart | python3 tool/verify_backup_restore.py
