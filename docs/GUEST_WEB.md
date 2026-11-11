# Browser guests

The guest page in `guest-web/public/` uses the existing Discord encrypted relay. No new backend, database, bot token, signing key, or GitHub credential belongs in the site. The desktop retains its SQLite ledger and must remain open/foreground to process guest requests. Safari on iPhone can open the page without installing an iOS app.

## Host and guest

In Shared trips, select **Invite guest by web link**, enter the guest name, choose the trip or profile, and select 24 hours, seven days or 30 days. The current default trip is selected initially. Each link grants access to one guest/trip. Seven days is the default. Send the link privately. The invitation key/webhook are in its URL fragment, which is not part of the HTTP request to Pages. The page removes the fragment after opening and retains the invitation only for the current tab session.

When the host creates a new web link, the app uploads an encrypted trip snapshot to that guest's Discord webhook. The private link contains the invitation key and the snapshot message ID in its URL fragment. A fresh browser can fetch and decrypt categories and all active currencies directly from Discord while the host is closed. Create a fresh link after changing currencies to give the guest the updated list. The guest needs no Discord account or iOS app. Older links without a stored snapshot still need one initial host response; generate a new web link for immediate use.

**Send expense** first saves an encrypted local pending entry, then posts it to Discord. Each successful Discord message receipt moves that entry to **Sent from this browser**. The browser sends every pending expense without waiting for host replies. After all entries say sent, the guest can close the page; the host automatically imports them when next opened/foreground. The browser retries failed uploads every ten seconds while visible and online, and stops retrying when the queue is empty or the page is hidden. Stable submission IDs let the host deduplicate uncertain transport retries.

“Sent to Discord” records transport receipt, rather than a completed SQLite insertion. The host still validates submissions and can reject invalid or revoked requests. Discord/channel/message deletion can prevent later delivery. The page shows the guest's invitation name. The trip total uses the host's default currency and rate from the timestamped snapshot. Create a new web link to share a newer snapshot.

Queue changes and sync use the browser’s [Web Locks API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API) to serialize access across tabs and reload the latest encrypted queue before each operation. Older browsers without this capability cannot submit; use a current Safari/Chrome/Firefox version.

The browser encrypts cached snapshots and pending expenses in local storage with the invitation key. Reopening the original invitation on the same browser/site can recover that queue. Private browsing, clearing site data, changing browsers or switching site domains can lose it. Keep the original link until all expenses have been received by Discord. This page has no service worker or background sync; loading it initially requires internet. Cached data remains on the guest device after expiry or revocation.

The host stores and enforces expiry independently of the link. It uses Discord’s trusted creation/last-edit timestamp, so expenses received before expiry can be imported after the host returns. Editing an old message after expiry is rejected. Editing a guest link cannot extend access. Existing native internet invitations remain compatible and keep their previous non-expiring behavior. Revoke an invitation from Shared trips to end access sooner. Removing a local queued item does not cancel a message already sent to Discord.

## Cloudflare Pages configuration

Production site: **https://expense-tracker-guest.pages.dev/**. Cloudflare Pages project: `expense-tracker-guest`, connected to `henrylyh3/expense-tracker` through the GitHub app installation scoped to this repository only.

Configured build settings:

- Production branch: `main`.
- Root directory: `guest-web`.
- Framework preset: None.
- Build command: `npm test` (tests run from the root directory).
- Build output directory: `public`.
- Build environment variable: `NODE_VERSION=22` (public, Production and Preview).
- Production build watch path: `guest-web/*`.
- No application environment variables or secrets are required by this static site.

Cloudflare deploys only `public`, keeping the fictional relay and crypto fixtures outside the published directory. `_headers` restricts scripts/styles to the site, connections to the Discord API/CDN, and disables referrers, framing and camera/microphone/location access. The repository's guest-web workflow checks the same focused protocol tests on pushes and pull requests.

The native app defaults to this verified production URL in `lib/core/sharing/guest_web.dart`, enabling **Invite guest by web link**. `GUEST_WEB_URL` can override it for a separate deployment. Keep a stable production domain: invitation links and encrypted browser queues are tied to its origin. The base page asks for an invitation; hosts generate private links from the app. No manual GitHub deployment token is needed by the Pages Git integration.

## Validation

Run `cd guest-web && npm test` for invitation parsing, AES-GCM authentication, money precision, encrypted storage, retry identity, acknowledgement validation, attachment restrictions, rate limiting and expiry. Native `discord_web_invite_test.dart` checks expiry persistence/enforcement, tampered guest endpoints, revocation after expiry and WebCrypto compatibility. `guest-web/test/browser.html` is a clearly labeled fictional relay for local UI checks; it is not deployed.

Chrome verified that a real invitation loads its encrypted Discord snapshot and enables expense entry. The fictional relay fixture verifies browser submission through the sent list. The default transport test checks that browser `fetch` keeps its global receiver during both snapshot loading and expense submission. Live expense delivery, Safari/iPhone behavior and installed native links still require acceptance testing. Automated checks use fictional credentials and expenses.
