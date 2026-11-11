const enc = new TextEncoder();
const dec = new TextDecoder('utf-8', { fatal: true });
const MAX_BYTES = 2 * 1024 * 1024;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SNOWFLAKE = /^\d{15,22}$/;
const MAX_INT = 9223372036854775807n;
export class GuestError extends Error {
  constructor(message, kind = 'error') { super(message); this.name = 'GuestError'; this.kind = kind; }
}
export function base64url(bytes) {
  let raw = ''; for (const byte of bytes) raw += String.fromCharCode(byte);
  return btoa(raw).replaceAll('+', '-').replaceAll('/', '_');
}
export function unbase64(value) {
  if (typeof value !== 'string' || value.length > MAX_BYTES * 2 || !/^[A-Za-z0-9_-]*={0,2}$/.test(value)) throw new GuestError('The invitation or encrypted reply is invalid.');
  try { return Uint8Array.from(atob(value.replaceAll('-', '+').replaceAll('_', '/')), c => c.charCodeAt(0)); }
  catch { throw new GuestError('The invitation or encrypted reply is invalid.'); }
}
function text(value, max = 80) {
  if (typeof value !== 'string' || !value.length || [...value].length > max || value.includes('\0')) throw new GuestError('The host sent an invalid trip view.');
  return value;
}
export function parseInvitation(source) {
  try {
    source = source.trim();
    if (source.startsWith('https://')) source = new URLSearchParams(new URL(source).hash.slice(1)).get('invite') ?? '';
    if (!source.startsWith('expense-trip:') || source.length > 4096) throw new Error();
    const data = JSON.parse(dec.decode(unbase64(source.slice(13))));
    if (data.version !== 2 || !UUID.test(data.id) || unbase64(data.key).length !== 32 || !data.endpoint.startsWith('discord:')) throw new Error();
    const endpoint = JSON.parse(dec.decode(unbase64(data.endpoint.slice(8))));
    const hook = new URL(endpoint.webhook);
    if (hook.protocol !== 'https:' || hook.hostname !== 'discord.com' || hook.username || hook.password || hook.port || hook.search || hook.hash || !/^\/api\/webhooks\/\d{15,22}\/[A-Za-z0-9_-]{20,200}$/.test(hook.pathname)) throw new Error();
    const expires = endpoint.expires_at == null ? null : Date.parse(endpoint.expires_at);
    if (expires !== null && (!Number.isFinite(expires) || typeof endpoint.expires_at !== 'string')) throw new Error();
    if (data.bootstrap != null && (typeof data.bootstrap !== 'string' || !SNOWFLAKE.test(data.bootstrap))) throw new Error();
    return { bootstrap: data.bootstrap ?? null, code: source, id: data.id, key: data.key, name: text(data.name), trip: text(endpoint.trip), webhook: hook.href, expires };
  } catch { throw new GuestError('This invitation is invalid. Ask the host for a complete web link or internet invitation.'); }
}
export async function seal(data, key, context) {
  const secret = await crypto.subtle.importKey('raw', unbase64(key), 'AES-GCM', false, ['encrypt']);
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const bytes = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce, additionalData: enc.encode(context), tagLength: 128 }, secret, enc.encode(JSON.stringify(data))));
  return { nonce: base64url(nonce), data: base64url(bytes.slice(0, -16)), mac: base64url(bytes.slice(-16)) };
}
export async function open(packet, key, context) {
  try {
    const nonce = unbase64(packet.nonce), ciphertext = unbase64(packet.data), mac = unbase64(packet.mac);
    if (nonce.length !== 12 || mac.length !== 16 || ciphertext.length > MAX_BYTES) throw new Error();
    const secret = await crypto.subtle.importKey('raw', unbase64(key), 'AES-GCM', false, ['decrypt']);
    const combined = new Uint8Array(ciphertext.length + mac.length); combined.set(ciphertext); combined.set(mac, ciphertext.length);
    const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: nonce, additionalData: enc.encode(context), tagLength: 128 }, secret, combined);
    return JSON.parse(dec.decode(plain));
  } catch { throw new GuestError('The encrypted reply could not be verified. Your pending expenses are kept.'); }
}
export function validateSnapshot(value) {
  if (!value || typeof value.total_myr_minor !== 'string' || !/^\d{1,19}$/.test(value.total_myr_minor) || BigInt(value.total_myr_minor) > MAX_INT || !Number.isSafeInteger(value.count) || value.count < 0 || !Number.isFinite(Date.parse(value.synced_at))) throw new GuestError('The host sent an invalid trip view.');
  text(value.name); text(value.default_currency);
  for (const field of ['categories', 'currencies', 'recent']) {
    if (!Array.isArray(value[field]) || value[field].length > (field === 'recent' ? 100 : 5000)) throw new GuestError('The host sent too many trip entries.');
    const ids = new Set();
    for (const row of value[field]) {
      if (field === 'recent') { text(row.category); text(row.amount); validDate(row.date); if (row.note != null && (typeof row.note !== 'string' || [...row.note].length > 500)) throw new GuestError('Invalid expense note.'); }
      else {
        text(row.id); text(row.name); if (ids.has(row.id)) throw new GuestError('The host sent duplicate trip entries.'); ids.add(row.id);
        if (field === 'currencies' && (!/^[A-Z]{3}$/.test(row.code) || !Number.isInteger(row.precision) || row.precision < 0 || row.precision > 6 || typeof row.rate !== 'string' || row.rate.length > 80 || !/^\d+(\.\d{1,12})?$/.test(row.rate) || !/[1-9]/.test(row.rate))) throw new GuestError('The host sent an invalid currency.');
      }
    }
  }
  return value;
}
function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value + 'T00:00:00Z')) || new Date(value + 'T00:00:00Z').toISOString().slice(0, 10) !== value) throw new GuestError('Choose a valid expense date.');
  return value;
}
export function makeExpense(snapshot, input) {
  if (!snapshot) throw new GuestError('Sync the trip before adding an expense.');
  const category = snapshot.categories.find(c => c.id === input.category);
  const currency = snapshot.currencies.find(c => c.id === input.currency);
  if (!category || !currency) throw new GuestError('Choose a category and currency from this trip.');
  if (typeof input.amount !== 'string' || input.amount.length > 40) throw new GuestError('Enter a valid amount.');
  let amount = input.amount.trim();
  if (/^\d{1,3}(,\d{3})+(\.\d+)?$/.test(amount)) amount = amount.replaceAll(',', '');
  const match = /^(\d+)(?:\.(\d+))?$/.exec(amount);
  const limit = currency.code === 'MYR' ? 2 : 6;
  if (!match || (match[2]?.length ?? 0) > limit) throw new GuestError(`Enter a positive amount with up to ${limit} decimal places.`);
  const precision = currency.code === 'MYR' ? 2 : Math.max(currency.precision, match[2]?.length ?? 0);
  const scaled = BigInt(match[1] + (match[2] ?? '').padEnd(precision, '0'));
  if (scaled <= 0n || scaled > MAX_INT) throw new GuestError('The amount must be positive and within the supported range.');
  const note = String(input.note ?? '').trim();
  if ([...note].length > 500 || note.includes('\0')) throw new GuestError('Keep the note within 500 characters.');
  return { category: category.id, currency: currency.code, amount, rate: currency.rate, date: validDate(input.date), note: note || null };
}
export function formatMyr(minor) {
  const number = BigInt(minor); return `RM ${(number / 100n).toLocaleString('en-MY')}.${(number % 100n).toString().padStart(2, '0')}`;
}
async function boundedJson(response) {
  if (Number(response.headers.get('content-length')) > MAX_BYTES) throw new GuestError('The relay reply is too large.');
  const reader = response.body?.getReader();
  let bytes;
  if (reader) {
    const parts = []; let size = 0;
    try { for (;;) { const { done, value } = await reader.read(); if (done) break; size += value.length; if (size > MAX_BYTES) { await reader.cancel(); throw new GuestError('The relay reply is too large.'); } parts.push(value); } }
    finally { reader.releaseLock(); }
    bytes = new Uint8Array(size); let offset = 0; for (const part of parts) { bytes.set(part, offset); offset += part.length; }
  } else { bytes = new Uint8Array(await response.arrayBuffer()); if (bytes.length > MAX_BYTES) throw new GuestError('The relay reply is too large.'); }
  try { return JSON.parse(dec.decode(bytes)); } catch { throw new GuestError('The relay returned an unreadable reply.'); }
}
export class RelayClient {
  constructor(invitation, {
    fetcher = (url, options) => globalThis.fetch(url, options),
    storage = localStorage,
    clock = Date.now,
    locks = globalThis.navigator?.locks,
  } = {}) {
    this.invite = invitation; this.fetcher = fetcher; this.storage = storage; this.clock = clock; this.locks = locks;
    this.state = { snapshot: null, pending: [], sent: [], read: null }; this.active = null; this.retryUntil = 0;
    this.slot = `expense-guest:${invitation.id}`;
  }
  get expired() { return this.invite.expires !== null && this.clock() >= this.invite.expires; }
  assertActive() { if (this.expired) throw new GuestError('This invitation has expired. Ask the host for a new link.', 'expired'); }
  async load() {
    let raw; try { raw = this.storage.getItem(this.slot); } catch { throw new GuestError('Browser storage is unavailable. Allow site storage before adding expenses.'); }
    if (raw) {
      if (raw.length > MAX_BYTES * 2) throw new GuestError('The saved queue is too large.');
      const state = await open(JSON.parse(raw), this.invite.key, `guest-cache:${this.invite.id}`);
      if (!Array.isArray(state.pending) || state.pending.length > 200 || state.pending.some(item => !UUID.test(item.id) || !item.expense)) throw new GuestError('The saved queue is invalid.');
      if (state.snapshot) validateSnapshot(state.snapshot);
      if (state.sent != null && (!Array.isArray(state.sent) || state.sent.length > 100 || state.sent.some(item => !UUID.test(item.id) || !item.expense || typeof item.message !== 'string' || !SNOWFLAKE.test(item.message)))) throw new GuestError('The saved delivery history is invalid.');
      this.state = { ...state, sent: state.sent ?? [] };
    }
    return this;
  }
  async persist() {
    while (enc.encode(JSON.stringify(this.state)).length > MAX_BYTES && this.state.sent.length) this.state.sent.pop();
    if (enc.encode(JSON.stringify(this.state)).length > MAX_BYTES) throw new GuestError('Trip details and pending expenses exceed browser storage limits. Send pending expenses before adding more.');
    const packet = await seal(this.state, this.invite.key, `guest-cache:${this.invite.id}`);
    try { this.storage.setItem(this.slot, JSON.stringify(packet)); } catch { throw new GuestError('Could not save on this device. Free browser storage and try again.'); }
  }
  async withStateLock(operation) {
    if (!this.locks?.request) throw new GuestError('This browser cannot safely save shared expenses. Update Safari or use a current browser.');
    return this.locks.request(this.slot, { mode: 'exclusive' }, async () => {
      // Another tab may have changed the encrypted queue since this view loaded.
      await this.load();
      return operation();
    });
  }
  async queue(input) {
    return this.withStateLock(async () => {
      this.assertActive();
      if (this.state.pending.length >= 200) throw new GuestError('Sync the pending expenses before adding more.');
      const item = { id: crypto.randomUUID(), expense: makeExpense(this.state.snapshot, input), createdAt: this.clock(), request: null, error: null };
      this.state.pending.push(item);
      try { await this.persist(); } catch (error) { this.state.pending.pop(); throw error; }
      return item;
    });
  }
  async remove(id) {
    return this.withStateLock(async () => {
      const previous = this.state.pending;
      this.state.pending = previous.filter(item => item.id !== id);
      try { await this.persist(); } catch (error) { this.state.pending = previous; throw error; }
    });
  }
  async request(url, { body, signal } = {}) {
    if (this.clock() < this.retryUntil) throw new GuestError('Discord is busy. Your queue is kept; try syncing later.', 'waiting');
    const controller = new AbortController(); const abort = () => controller.abort();
    if (signal?.aborted) controller.abort(); else signal?.addEventListener('abort', abort, { once: true });
    const timer = setTimeout(abort, 20000);
    try {
      const response = await this.fetcher(url, { method: body ? 'POST' : 'GET', body, signal: controller.signal, credentials: 'omit', redirect: 'error', referrerPolicy: 'no-referrer' });
      if (response.status === 429) {
        const data = await boundedJson(response); const seconds = Math.min(3600, Math.max(1, Number(data.retry_after) || 30));
        this.retryUntil = this.clock() + Math.ceil(seconds * 1000);
        throw new GuestError('Discord is busy. Your queue is kept; try syncing later.', 'waiting');
      }
      if (response.status === 404) throw new GuestError('Relay message not found.', 'not-found');
      if (!response.ok) throw new GuestError('Could not reach the trip relay. Your queue is kept.');
      return await boundedJson(response);
    } catch (error) {
      if (error instanceof GuestError) throw error;
      throw new GuestError(controller.signal.aborted ? 'Sync stopped. Your pending expenses are kept.' : 'Connection unavailable. Your pending expenses are kept.', 'offline');
    } finally { clearTimeout(timer); signal?.removeEventListener('abort', abort); }
  }
  async sendRequest(data, slot, signal) {
    this.assertActive();
    if (!slot.request) {
      const request = crypto.randomUUID();
      const encrypted = await seal({ ...data, request, trip: this.invite.trip }, this.invite.key, `discord-request:${this.invite.id}:${this.invite.trip}`);
      const form = new FormData();
      form.set('payload_json', JSON.stringify({ content: 'Expense Tracker encrypted sync', allowed_mentions: { parse: [] }, attachments: [{ id: 0, filename: 'expense-relay.json' }] }));
      form.set('files[0]', new Blob([JSON.stringify({ direction: 'request', id: this.invite.id, ...encrypted })], { type: 'application/json' }), 'expense-relay.json');
      let message;
      try { message = await this.request(`${this.invite.webhook}?wait=true`, { body: form, signal }); }
      catch (error) { if (error.kind === 'not-found') throw new GuestError('This invitation is no longer available. Ask the host for a new link.', 'revoked'); throw error; }
      if (typeof message.id !== 'string' || !SNOWFLAKE.test(message.id)) throw new GuestError('The relay did not confirm receipt. Your queue is kept.');
      slot.request = { message: message.id, id: request }; await this.persist();
    }
    if (typeof slot.request.message !== 'string' || !SNOWFLAKE.test(slot.request.message) || !UUID.test(slot.request.id)) throw new GuestError('The saved relay request is invalid.');
  }
  async exchange(data, slot, signal) {
    await this.sendRequest(data, slot, signal);
    let message;
    try { message = await this.request(`${this.invite.webhook}/messages/${slot.request.message}`, { signal }); }
    catch (error) {
      if (error.kind === 'not-found') {
        try { await this.request(this.invite.webhook, { signal }); }
        catch (check) { if (check.kind === 'not-found') throw new GuestError('This invitation is no longer available. Ask the host for a new link.', 'revoked'); throw check; }
        slot.request = null; await this.persist();
        throw new GuestError('The relay message was removed. Your expense is kept; sync again.', 'waiting');
      }
      throw error;
    }
    const packet = await this.attachmentPacket(message, signal);
    if (packet.direction !== 'response') throw new GuestError('Waiting for the host to open the app and process your request.', 'waiting');
    if (packet.id !== this.invite.id) throw new GuestError('The reply belongs to a different invitation.');
    const response = await open(packet, this.invite.key, `discord-response:${this.invite.id}:${slot.request.id}`);
    if (response.request !== slot.request.id) throw new GuestError('The reply could not be matched to this request.');
    if (typeof response.error === 'string') {
      slot.request = null; await this.persist();
      throw new GuestError(response.error.slice(0, 300), /expired/i.test(response.error) ? 'expired' : 'rejected');
    }
    validateSnapshot(response.snapshot);
    return response;
  }
  async attachmentPacket(message, signal) {
    const file = message.attachments?.find(item => item.filename === 'expense-relay.json');
    if (!file) throw new GuestError('Waiting for the host to open the app and process your request.', 'waiting');
    const attachment = new URL(file.url);
    if (attachment.protocol !== 'https:' || !['cdn.discordapp.com', 'media.discordapp.net'].includes(attachment.hostname) || attachment.port || attachment.username || attachment.password || attachment.hash || !attachment.pathname.startsWith('/attachments/') || !Number.isSafeInteger(file.size) || file.size < 0 || file.size > MAX_BYTES) throw new GuestError('The relay attachment is invalid.');
    return this.request(attachment.href, { signal });
  }
  async ensureSnapshot(signal) {
    if (this.state.snapshot) return;
    if (this.invite.bootstrap) {
      let message;
      try { message = await this.request(`${this.invite.webhook}/messages/${this.invite.bootstrap}`, { signal }); }
      catch (error) {
        if (error.kind === 'not-found') throw new GuestError('This invitation is no longer available. Ask the host for a new web link.', 'revoked');
        throw error;
      }
      const packet = await this.attachmentPacket(message, signal);
      if (packet.direction !== 'invite' || packet.id !== this.invite.id) throw new GuestError('The invitation details could not be verified.');
      const view = await open(packet, this.invite.key, `discord-invite:${this.invite.id}:${this.invite.trip}`);
      this.state.snapshot = validateSnapshot(view.snapshot);
    } else {
      // Earlier links require one initial host response; newly created web links do not.
      this.state.read ??= { request: null };
      const response = await this.exchange({ action: 'read' }, this.state.read, signal);
      this.state.snapshot = response.snapshot;
    }
    this.state.read = null;
    await this.persist();
  }
  sync({ signal, onProgress = () => {} } = {}) {
    if (this.active) return this.active;
    this.active = this.withStateLock(() => this.performSync(signal, onProgress)).finally(() => { this.active = null; }); return this.active;
  }
  async performSync(signal, onProgress) {
    this.assertActive(); this.lastSentCount = 0;
    onProgress('Loading invitation details from Discord');
    await this.ensureSnapshot(signal);
    const total = this.state.pending.length;
    for (const item of [...this.state.pending]) {
      onProgress(`Sending expense ${this.lastSentCount + 1} of ${total} to Discord`);
      // A Discord message receipt is sufficient; the host can import it later.
      await this.sendRequest({ action: 'add', reply: false, submission: item.id, expense: item.expense }, item, signal);
      const pending = this.state.pending, sent = this.state.sent;
      this.state.sent = [{ id: item.id, expense: item.expense, message: item.request.message, sentAt: this.clock() }, ...sent].slice(0, 100);
      this.state.pending = pending.filter(row => row.id !== item.id);
      try { await this.persist(); }
      catch (error) { this.state.pending = pending; this.state.sent = sent; throw error; }
      this.lastSentCount++;
    }
    return this.state.snapshot;
  }
}
