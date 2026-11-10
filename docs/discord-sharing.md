# Discord sharing

Available starting in v0.4.6. The local ledger remains authoritative.

## One-time host setup

1. Create a private Discord server and regular private text channel.
2. Create an application/bot in the Discord Developer Portal. Enable Message Content Intent.
3. Install the bot with View Channel, Read Message History, Send Messages and Manage Webhooks in that channel.
4. Enable Discord Developer Mode and copy the channel ID.
5. In Settings > Shared trips > Configure internet sharing, enter the channel ID and bot token. Verify and save.

The app creates webhooks automatically; no manual webhook URL is needed. The bot token is stored in device secure storage, never included in invitations or ledger exports. Keep the channel private. Discord limits the number of webhooks per channel; the app reports a setup/permission error if creation is refused. Revoke unused invitations to free webhook slots.

## Invite and sync

Choose the current trip, then Invite guest over internet. Each invitation contains its unique guest/session ID, trip ID, webhook and AES-GCM key. Share it privately. Guests join through Join using invitation, with no Discord account.

The guest syncs once to fetch categories, currencies and the latest trip view. The first Sync sends a read request. The host processes it while open; the guest taps Sync again to receive the view. Expenses can then be queued offline. Sync submits them to Discord; they remain pending until the host inserts them and returns an authenticated acknowledgement. A later guest Sync collects that acknowledgement. Internet is needed on both sides at sync time; they do not need to be online simultaneously.

The host polls every 30 seconds while the app is in the foreground and the ledger is ready. Process internet inbox also triggers a poll. Do not depend on background execution, especially on iOS. Guests see the latest host snapshot, not a live ledger. At most 100 recent expenses are included.

## Browser guests without an online host

Starting with v0.4.10, **Invite guest by web link** stores an encrypted initial trip snapshot in Discord. New links let a fresh browser load the form and send expenses with the desktop closed. The guest sends each queued expense directly to Discord and sees **Sent to Discord** as soon as Discord returns its message receipt. No host acknowledgement or guest revisit is required for successfully sent expenses. Failed/offline uploads stay in the browser until it reconnects while visible. The host validates and inserts received expenses automatically when opened later.

Expiry uses Discord's creation/last-edit timestamp: legitimate pre-expiry messages can be imported after expiry; late posts or edits cannot extend access. Revocation still removes local authorization and the webhook. Existing native guest applications retain their acknowledgement/retry protocol. See [browser guest details](GUEST_WEB.md).

## Protocol and recovery

Requests and responses are AES-256-GCM encrypted JSON attachments, with authenticated context bound to invitation, trip and request. Host responses replace the original webhook message. This allows guests to retrieve the specific reply using their webhook credentials without getting the bot token or channel history access. Decrypted payloads are validated before insertion. Stable submission IDs and SQLite receipts prevent duplicate inserts after retries, lost acknowledgements or restart. Guest request/message IDs and the host cursor survive restart in secure storage. Multiple inbox pages are fetched after the saved cursor. Rate-limit errors preserve queues and delay subsequent API requests.

Removing a guest first removes local authorisation and schedules webhook deletion. If Discord is unavailable, local access is still revoked; webhook deletion retries on a later host poll. Deleted webhooks show guests that the sharing connection is no longer available, not a guaranteed explanation of who deleted it. Unconfirmed expenses remain local. Discarding a local item does not cancel a message already sent to Discord.

Discord stores encrypted relay messages and transport metadata. This is not a guaranteed queue or ledger backup; deletion of a channel/message or interruption of Discord can delay or interrupt delivery. Local requests are retained until host acknowledgement. Export a ledger backup separately. Reset clears local sharing credentials and invitations; it does not delete a Discord channel or its messages. Before resetting or restoring, revoke internet invitations if you want their remote webhooks removed.

## Testing limits

Automated tests use a deterministic Discord API substitute to cover invitation isolation, encryption, queued delivery, retries, restart, revocation, permission binding and pagination. A real Discord bot/channel and two physical devices are needed for live acceptance checks. iOS signing/build requires macOS/Xcode.
