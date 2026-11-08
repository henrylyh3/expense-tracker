# Shared trips over local Wi-Fi or hotspot

The host phone owns the trip ledger. Guests keep a cached view and an offline queue of their expenses. There is no cloud database or Internet relay in this version.

## Host

1. Select the trip under Settings → Trips and profiles.
2. Open Settings → Shared trips and press Start hosting.
3. Choose Invite guest to this trip, enter the guest name, and confirm the host phone's Wi-Fi or hotspot IPv4 address.
4. Send the invitation privately. Create a separate invitation for each guest.
5. Keep the app open and the phone awake while guests sync. The host listens on port 45873. A Wi-Fi access point with client isolation may prevent phones from reaching each other.

Open an invited guest entry to revoke access. Submitted expenses remain in the host's ledger. A revoked guest may retain data already received.

## Guest

1. Join the host's Wi-Fi or hotspot.
2. In Settings → Shared trips, choose Join using invitation and paste the complete invitation code.
3. Open the joined trip and press Sync with host once to load categories, currencies and the host's summary.
4. Add shared expenses from this screen. They stay queued locally until Sync with host succeeds.
5. If the host address changes, update it on the joined trip screen. If a queued expense can no longer be accepted, it can be discarded explicitly and entered again using refreshed choices.

The cached host total excludes unsent expenses and shows the last sync time. Guests can view and add expenses. They cannot edit or delete the host's existing expenses through sharing. The host manages its authoritative ledger normally.

## Data and transport

Messages use AES-256-GCM with a unique random invitation key and authenticated request/response contexts. The local HTTP connection carries encrypted messages. Each queued expense has a stable identifier, and the host stores its acknowledgement in the same transaction as the expense to avoid duplicates after retries. The invitation key is a bearer credential, so anyone who receives a copy can use that guest invitation until revoked.

Invitations, credentials, caches and unsent guest queues are device-local and excluded from normal JSON export. Sync unsent expenses before resetting, importing or leaving a shared trip. Reset/import revokes this device's host invitations and clears guest queues. Backups of the host ledger include already-submitted expenses. This version does not run a background Android hosting service, synchronize while the host is offline, or connect phones across different networks.
