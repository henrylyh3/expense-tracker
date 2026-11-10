# Browser guests

The guest page in `guest-web/public/` uses the existing Discord encrypted relay. No new backend, database, bot token, signing key, or GitHub credential belongs in the site. The desktop retains its SQLite ledger and must remain open/foreground to process guest requests. Safari on iPhone can open the page without installing an iOS app.

## Host and guest

In Shared trips, select **Invite guest by web link**, enter the guest name and choose 24 hours, seven days or 30 days. Each link grants access to one guest/trip. Seven days is the default. Send the link privately. The invitation key/webhook are in its URL fragment, which is not part of the HTTP request to Pages. The page removes the fragment after opening and retains the invitation only for the current tab session.

The first sync obtains categories, currencies and the latest trip view. Save expenses to the local queue, then keep the page visible and connected. Pending requests are checked every ten seconds; an idle visible trip refreshes every minute. Both operations stop when hidden. A stable submission ID prevents duplicate ledger inserts after retries. Only an authenticated host acknowledgement removes a queued expense.

The browser encrypts cached snapshots and pending expenses in local storage with the invitation key. Reopening the original invitation on the same browser/site can recover that queue. Private browsing, clearing site data, changing browsers or switching site domains can lose it. Keep the original link until all expenses are confirmed. This page has no service worker or background sync; loading it initially requires internet. Cached data remains on the guest device after expiry or revocation.

The host stores and enforces expiry independently of the link. Editing a guest link cannot extend access. Existing native internet invitations remain compatible and keep their previous non-expiring behavior. Revoke an invitation from Shared trips to end access sooner. Removing a local queued item does not cancel a message already sent to Discord.

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

Live signed Discord attachment delivery, Safari/iPhone behavior and installed native links require a real invitation and physical-device acceptance testing. No real bot credentials or expense messages are used by automated checks.
