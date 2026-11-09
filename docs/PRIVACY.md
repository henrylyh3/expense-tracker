# Privacy and local data

Expense Tracker has no online account, external ledger backend,
advertising, analytics or crash-reporting service. Shared-trip access uses private invitation keys. Personal ledger operations require no internet connection. Optional shared trips use local Wi-Fi or hotspot networking. New currencies can prefill Frankfurter reference rates; rates remain editable and fixed after saving.

On Android, the app checks GitHub Releases for updates on startup, on foreground return after at least five minutes, and when you explicitly check in Settings. GitHub receives the network request (including the device's public IP address and updater user agent); no ledger, trip, invitation or backup data is sent. Choosing Update now downloads a signed APK from GitHub. The temporary update cache is separate from ledger storage and excluded from ledger exports. Android installation permission is used only after you choose to update. See [UPDATES.md](UPDATES.md).

When you choose or type a currency while creating a new record, the app requests its latest reference rate to MYR from api.frankfurter.dev. The request identifies the currency pair; no expense amounts, notes, trip names or invitations are transmitted. The network connection exposes its public IP address to the service/infrastructure. The returned rate is only a suggested form value: it does not refresh saved rates or rewrite existing expenses. Offline users can enter a rate manually. See [CURRENCY_RATES.md](CURRENCY_RATES.md).

Transactions, notes, categories, currencies, saved rates and appearance settings
are stored in private SQLite storage on the device. All reports use saved MYR
conversions. SQLite is not separately encrypted by this app; protection relies on
the operating system's app sandbox and device security.

Internal ledger storage is configured to be excluded from automatic Android
backup/device transfer and iOS backup. iOS also applies file protection. These
settings require physical-device verification; they are not a promise of
protection on a compromised device or against every manufacturer/OS behavior.
Uninstalling the app or losing the device can lose the ledger without a backup.

The app exports files only when you choose a backup action. When you enable shared-trip hosting, invited guests can read that trip and submit expenses while the host is reachable. Peer messages are encrypted using AES-GCM with a separate invitation key per guest. Invitations grant access and must be shared privately. No cloud ledger or relay is used. JSON backups
contain the full ledger and notes in readable, unencrypted form. Choose a private
destination and protect copies. The operating system's file/share interface may
include other apps or cloud providers; their handling of a selected backup is
outside this app. Import requires a locally readable file when offline.

Shared files are placed in OS temporary cache so the selected recipient can read
them after the share dialog closes. On a subsequent share, owned files older than
24 hours are removed; the OS may also remove cache. This is not a guaranteed
24-hour deletion or secure erase. A share completion signal does not prove that
a recoverable backup was saved.

Sharing keys and cached guest views are stored in private local SQLite. Invitations, cached views and unsent guest expenses are excluded from ledger exports. Reset and import remove these local sharing records. Guests may retain data already received after access is revoked.

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
