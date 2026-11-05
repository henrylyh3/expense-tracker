# Migration policy

Schema version 1 creates tables/indexes/triggers and seeds defaults once.
There is no historical upgrade path yet. Unknown upgrades fail safely.

The real v1 snapshot/helper are now generated and host-tested. Normal checks use
`bash tool/check_schema.sh` to compare a temporary export without overwriting
history. When intentionally exporting a new version:

```sh
dart run build_runner build
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

Commit generated `.g.dart`, `pubspec.lock`, exported snapshots and historical
test helpers with the source. Never handwrite generated code. The baseline tests
compare fresh creation to exported v1, open v1 without reseeding and reject a
synthetic future database without changing its schema/data. There is no released
v1-to-v2 upgrade path yet.

For each future change, retain snapshots, increment schemaVersion, implement
ordered migrations using Drift tooling, regenerate and test all supported
upgrade paths including data preservation and constraints. Trigger and index
changes also require a versioned migration. Keep migrations independent of
current seeds/model constructors. Never drop/reset the ledger on errors.

Replace All restore must preserve MYR: delete transactions, then other
currencies/categories/settings, update MYR metadata and insert restored data
inside one transaction. Do not disable foreign keys for restore.
