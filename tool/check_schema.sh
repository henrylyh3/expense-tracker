#!/usr/bin/env bash
# Compare a fresh Drift export without overwriting any historical snapshot.
set -euo pipefail
cd "$(dirname "$0")/.."
dart_bin="${DART_BIN:-dart}"
schema_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/expense-tracker-schema.XXXXXX")"
trap 'rm -rf "$schema_check_dir"' EXIT
"$dart_bin" run drift_dev schema dump lib/core/database/app_database.dart "$schema_check_dir/"
python3 - "$schema_check_dir" <<'PY'
import json
from pathlib import Path
import sys

exported = list(Path(sys.argv[1]).glob('drift_schema_v*.json'))
if len(exported) != 1:
    sys.exit('Expected one generated schema snapshot.')
expected = Path('drift_schemas') / exported[0].name
if not expected.exists():
    sys.exit(f'Missing {expected}; export and review the new schema version.')
def normalize_line_endings(value):
    if isinstance(value, str):
        return value.replace('\r\n', '\n')
    if isinstance(value, list):
        return [normalize_line_endings(item) for item in value]
    if isinstance(value, dict):
        return {key: normalize_line_endings(item) for key, item in value.items()}
    return value


def load_schema(path):
    return normalize_line_endings(json.loads(path.read_text(encoding='utf-8')))


if load_schema(expected) != load_schema(exported[0]):
    sys.exit('Schema differs from its versioned snapshot. Add a versioned migration; do not overwrite a released snapshot.')
print(f'Schema matches {expected}.')
PY
