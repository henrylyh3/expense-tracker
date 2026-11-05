# Privacy and local data

Expense Tracker has no account, authentication, backend, exchange-rate API,
advertising, analytics or crash-reporting service. The app's own financial
operations require no internet connection. Exchange rates are entered manually.

Transactions, notes, categories, currencies, saved rates and appearance settings
are stored in private SQLite storage on the device. All reports use saved MYR
conversions. SQLite is not separately encrypted by this app; protection relies on
the operating system's app sandbox and device security.

Internal ledger storage is configured to be excluded from automatic Android
backup/device transfer and iOS backup. iOS also applies file protection. These
settings require physical-device verification; they are not a promise of
protection on a compromised device or against every manufacturer/OS behavior.
Uninstalling the app or losing the device can lose the ledger without a backup.

The app exports or shares data only when you choose a backup action. JSON backups
contain the full ledger and notes in readable, unencrypted form. Choose a private
destination and protect copies. The operating system's file/share interface may
include other apps or cloud providers; their handling of a selected backup is
outside this app. Import requires a locally readable file when offline.

Shared files are placed in OS temporary cache so the selected recipient can read
them after the share dialog closes. On a subsequent share, owned files older than
24 hours are removed; the OS may also remove cache. This is not a guaranteed
24-hour deletion or secure erase. A share completion signal does not prove that
a recoverable backup was saved.

Restoring replaces the ledger and settings after validation and explicit
confirmation. A safety backup is offered by default. Cancelling or failing that
save cancels restoration. Copies already saved/shared elsewhere are not deleted
when the ledger is edited, replaced or the app is uninstalled.

The app reads internal file metadata for storage and temporary-share cleanup,
and metadata of a backup you explicitly select to enforce its size limit. That
metadata is not used to identify or track users. The iOS app manifest records
these reasons; release archives must also include and review dependency manifests.

This document describes current app behavior. Before public distribution, the
publisher must supply their identity/contact and an appropriate published policy
URL, verify the signed application's behavior and complete accurate store forms.
No external privacy page has been published by this project.
