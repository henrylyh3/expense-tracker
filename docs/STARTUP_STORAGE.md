# Startup and local-storage hardening

Phase 6 follow-up, 2026-11-05 (Malaysia).

## Behavior

The database-ready Riverpod provider must complete before the app shows its
ledger screens. Previously initialization established that settings could be
queried and foreign keys were enabled. It now verifies an existing ledger's
schema presence and storage integrity before opening the dashboard.

Opening/migrations finish first. A read-only SQLite transaction then checks:

1. Foreign-key enforcement is enabled for the connection.
2. Generated tables, indexes, triggers and views exist with the expected kind.
3. Each table has the column names expected by the generated database.
4. SQLite quick_check(1) succeeds.
5. No existing foreign-key violation is reported. A table-valued pragma with
   LIMIT 1 bounds the returned error rows.
6. MYR exists, is active, has precision 2 and rate text exactly `1`.
7. theme_mode exists and is System, Light or Dark.

These checks never recreate schema objects, reseed missing rows, delete files or
rewrite values. First creation still uses the existing transactional migration
and seeds. An intentionally empty valid ledger stays empty. Unsupported future
versions still fail through the existing migration policy.

Failure reaches the existing startup error screen with Retry, without database
paths or raw SQL error details. The message explains that the ledger has not been
reset/repaired and advises preserving the installation and existing backups if
retry does not help. SQLite exceptions also leave the file in place; a regression
test verifies the bytes of a non-SQLite file are unchanged after a failed open.

## Private storage boundary

private_storage.dart owns the existing method channel. It accepts only a nonempty,
absolute filesystem directory without a NUL byte. Spaces within a valid path are
supported. Null, relative paths and file-URI strings fail. Missing native plugins
and native storage errors propagate to startup failure, never a fallback directory.

The Android/iOS implementations still prepare backup exclusion/file protection
before returning the directory. No native storage location or database filename
changed. The bridge tests mock only the method-channel boundary; actual sandbox,
backup-exclusion and file-protection behavior still needs device verification.

## Important files

| File | Responsibility |
| --- | --- |
| lib/core/database/database_health.dart | Consistent read-only schema/storage checks |
| lib/core/database/app_database.dart | Completes open/migrations, then runs checks |
| lib/core/database/private_storage.dart | Native private-directory request and path validation |
| lib/core/database/database_connection.dart | Wires the prepared directory into background Drift |
| lib/app/app.dart | Loading/error gate and preservation guidance |
| test/core/database/database_health_test.dart | Missing objects, invalid data/settings, empty ledger and unreadable file cases |
| test/core/database/private_storage_test.dart | Native response and failure boundary cases |
| test/app/app_test.dart | Real schema failure blocks navigation and preserves ledger rows |

## Verification and limits

Twenty-one new tests pass: twelve database health checks, eight native bridge
boundary checks and one real-database startup widget regression. Together with
the existing tests, all **194 Flutter tests**, full analysis, schema comparison
and **25 SQLite checks** pass through tool/check.sh. Schema version remains 1;
the exported baseline is unchanged. No dependencies were added.

In production, the SQLite work runs on the existing Drift background executor.
quick_check still scans data; the argument limits errors returned, not rows
examined. Check cold-start latency with large ledgers on supported test devices.

This is an early failure check, not a complete schema or financial audit.
Presence/column-name checks do not compare every constraint, affinity or trigger
body. quick_check does not replace the more expensive integrity_check's index
and uniqueness checks. Financial calculations remain validated by repositories
and the backup validator. Historical schema equivalence is tested separately by
the exported-schema tests and the check script.

No automatic repair or recovery into an unreadable database is implemented.
Normal JSON restore is available after the ledger opens successfully. Recovery
when the ledger cannot open needs a separately designed, explicitly confirmed
workflow that preserves the original SQLite/WAL files; deleting the ledger or
reinstalling is not an automatic retry strategy.

Official stable-SDK validation and Android/iOS builds/device acceptance are still
pending; see [Phase 6](PHASE_6_RELEASE.md) and [progress](PROGRESS.md).

Reference: [SQLite pragma documentation](https://www.sqlite.org/pragma.html)
(quick_check, foreign_key_check and table-valued pragmas).
