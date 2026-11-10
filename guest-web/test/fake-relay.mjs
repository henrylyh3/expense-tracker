// Fictional data and credentials, used only by tests. Never deployed.
import { base64url, open, seal, RelayClient, parseInvitation } from '../public/protocol.mjs';
const encode = data => base64url(new TextEncoder().encode(JSON.stringify(data)));
export const key = base64url(new Uint8Array(32).fill(7));
export const endpoint = { webhook: 'https://discord.com/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz123456', trip: 'personal' };
export const bootstrapId = '100000000000000000';
export const invitationData = { bootstrap: bootstrapId, version: 2, id: '12345678-1234-4234-8234-123456789012', key, name: 'Test guest', endpoint: `discord:${encode(endpoint)}` };
export const invitationCode = `expense-trip:${encode(invitationData)}`;
export const snapshot = { name: 'Test trip', total_myr_minor: '1250', count: 1, default_currency: 'MYR', categories: [{ id: 'seed-food', name: 'Food' }], currencies: [{ id: 'MYR', code: 'MYR', name: 'Malaysian ringgit', precision: 2, rate: '1' }, { id: 'JPY', code: 'JPY', name: 'Japanese yen', precision: 0, rate: '0.03' }], recent: [{ category: 'Food', amount: 'RM 12.50', date: '2026-11-10', note: 'Test lunch' }], synced_at: '2026-11-10T00:00:00Z' };
export const input = { category: 'seed-food', currency: 'MYR', amount: '12.50', date: '2026-11-10', note: 'Private lunch note' };
export function memoryStorage() { const data = new Map(); return { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value), data }; }
function memoryLocks() {
  let tail = Promise.resolve();
  return { request(_name, _options, callback) { const result = tail.then(callback); tail = result.catch(() => {}); return result; } };
}
export class FakeRelay {
  constructor() { this.locks = memoryLocks(); this.messages = new Map([[bootstrapId, { invite: true }]]); this.posts = 0; this.calls = []; this.waiting = false; this.revoked = false; this.rateLimit = false; this.saved = new Set(); this.badAttachment = false; this.wrongId = false; this.failAfterPosts = Infinity; this.loseReceiptOnce = false; this.badReceipt = false; }
  async fetch(url, options) {
    this.calls.push({ url, options });
    if (this.rateLimit) return Response.json({ retry_after: 2 }, { status: 429 });
    if (this.revoked) return Response.json({}, { status: 404 });
    if (options.method === 'POST') {
      if (this.posts >= this.failAfterPosts) throw new TypeError('Offline');
      this.posts++;
      const packet = JSON.parse(await options.body.get('files[0]').text());
      const request = await open(packet, key, `discord-request:${invitationData.id}:${endpoint.trip}`);
      const id = String(100000000000000000n + BigInt(this.posts)); this.messages.set(id, { request, packet });
      if (this.loseReceiptOnce) { this.loseReceiptOnce = false; throw new TypeError('Receipt lost'); }
      return Response.json({ id: this.badReceipt ? null : id });
    }
    if (url.startsWith('https://cdn.discordapp.com/')) {
      const row = this.messages.get(new URL(url).pathname.split('/').at(-1));
      if (row.invite) return Response.json({ direction: 'invite', id: this.wrongId ? 'wrong-id' : invitationData.id, ...await seal({ snapshot: structuredClone(snapshot) }, key, `discord-invite:${invitationData.id}:${endpoint.trip}`) });
      if (this.waiting) return Response.json(row.packet);
      const response = { request: row.request.request, snapshot: structuredClone(snapshot) };
      if (row.request.action === 'add') { this.saved.add(row.request.submission); response.saved = 'transaction-id'; }
      return Response.json({ direction: 'response', id: this.wrongId ? 'wrong-id' : invitationData.id, ...await seal(response, key, `discord-response:${invitationData.id}:${row.request.request}`) });
    }
    if (url.includes('/messages/')) {
      const id = url.split('/').at(-1); if (!this.messages.has(id)) return Response.json({}, { status: 404 });
      return Response.json({ attachments: [{ filename: 'expense-relay.json', size: 1024, url: this.badAttachment ? 'https://evil.example/attachments/file' : `https://cdn.discordapp.com/attachments/test/${id}?signed=test` }] });
    }
    return Response.json({ id: '123456789012345' });
  }
  receive() { for (const row of this.messages.values()) if (row.request?.action === 'add') this.saved.add(row.request.submission); }
  client(storage = memoryStorage(), extra = {}) { return new RelayClient(parseInvitation(invitationCode), { fetcher: this.fetch.bind(this), storage, locks: this.locks, ...extra }); }
}
