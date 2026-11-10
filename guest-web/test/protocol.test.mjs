import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseInvitation, seal, open, makeExpense, formatMyr, validateSnapshot, base64url } from '../public/protocol.mjs';
import { FakeRelay, snapshot, input, key, invitationCode, invitationData, endpoint, memoryStorage } from './fake-relay.mjs';
const encode = data => base64url(new TextEncoder().encode(JSON.stringify(data)));
test('invitation accepts URL fragments and rejects unsafe webhook destinations', () => {
  assert.equal(parseInvitation(`https://example.pages.dev/#invite=${invitationCode}`).id, invitationData.id);
  for (const webhook of ['http://discord.com/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz', 'https://evil.example/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz', endpoint.webhook + '?token=bad']) {
    const data = { ...invitationData, endpoint: 'discord:' + encode({ ...endpoint, webhook }) };
    assert.throws(() => parseInvitation('expense-trip:' + encode(data)), /invitation is invalid/);
  }
});
test('AES-GCM round trip authenticates context and tampering', async () => {
  const packet = await seal({ amount: '12.50' }, key, 'context');
  assert.deepEqual(await open(packet, key, 'context'), { amount: '12.50' });
  await assert.rejects(open(packet, key, 'another'), /could not be verified/);
  await assert.rejects(open({ ...packet, mac: base64url(new Uint8Array(16)) }, key, 'context'), /could not be verified/);
});
test('money preserves exact decimals, foreign fractional units and 64-bit totals', () => {
  assert.equal(makeExpense(snapshot, { ...input, currency: 'JPY', amount: '1.234567' }).amount, '1.234567');
  assert.throws(() => makeExpense(snapshot, { ...input, amount: '1.234' }), /2 decimal/);
  assert.throws(() => makeExpense(snapshot, { ...input, amount: '0' }), /positive/);
  assert.throws(() => makeExpense(snapshot, { ...input, date: '2026-02-30' }), /valid expense date/);
  assert.throws(() => makeExpense(snapshot, { ...input, amount: '1'.repeat(100) }), /valid amount/);
  assert.equal(formatMyr('9007199254740993'), 'RM 90,071,992,547,409.93');
  assert.throws(() => validateSnapshot({ ...snapshot, total_myr_minor: 1250 }), /invalid trip/);
});
test('fresh link loads with host offline and all expenses send without host replies', async () => {
  const fake = new FakeRelay(), client = fake.client(); fake.waiting = true;
  await client.sync(); assert.equal(client.state.snapshot.name, snapshot.name); assert.equal(fake.posts, 0);
  const ids = [];
  for (let i = 0; i < 3; i++) ids.push((await client.queue({ ...input, note: `Expense ${i}` })).id);
  const gets = fake.calls.filter(row => row.options.method === 'GET').length;
  await client.sync();
  assert.equal(client.state.pending.length, 0); assert.equal(client.state.sent.length, 3); assert.equal(fake.posts, 3);
  assert.equal(fake.calls.filter(row => row.options.method === 'GET').length, gets);
  assert.equal(fake.saved.size, 0); // Host has not received/processed its inbox yet.
  fake.receive(); assert.deepEqual(fake.saved, new Set(ids));
});
test('partial upload survives restart, encrypted history and sends remaining items only', async () => {
  const fake = new FakeRelay(), storage = memoryStorage(), client = fake.client(storage); await client.sync();
  for (let i = 0; i < 3; i++) await client.queue(input);
  fake.failAfterPosts = 1; await assert.rejects(client.sync(), error => error.kind === 'offline');
  assert.equal(client.state.pending.length, 2); assert.equal(client.state.sent.length, 1);
  assert.ok(!storage.getItem(client.slot).includes('Private lunch note'));
  const restored = await fake.client(storage).load(); fake.failAfterPosts = Infinity; await restored.sync();
  assert.equal(fake.posts, 3); assert.equal(restored.state.pending.length, 0); assert.equal(restored.state.sent.length, 3);
});
test('lost Discord receipt retries same submission id for host deduplication', async () => {
  const fake = new FakeRelay(), client = fake.client(); await client.sync(); const item = await client.queue(input);
  fake.loseReceiptOnce = true; await assert.rejects(client.sync(), error => error.kind === 'offline');
  assert.equal(client.state.pending[0].id, item.id);
  await client.sync(); assert.equal(fake.posts, 2); fake.receive(); assert.deepEqual(fake.saved, new Set([item.id]));
});
test('older cached pending receipt moves to sent history without repost or host acknowledgement', async () => {
  const fake = new FakeRelay(), storage = memoryStorage(), client = fake.client(storage); await client.sync(); const item = await client.queue(input);
  await client.withStateLock(() => client.sendRequest({ action: 'add', submission: item.id, expense: item.expense }, client.state.pending[0]));
  const old = { ...client.state }; delete old.sent;
  storage.setItem(client.slot, JSON.stringify(await seal(old, key, `guest-cache:${invitationData.id}`)));
  const posts = fake.posts, calls = fake.calls.length, restored = await fake.client(storage).load(); await restored.sync();
  assert.equal(fake.posts, posts); assert.equal(fake.calls.length, calls); assert.equal(restored.state.pending.length, 0); assert.equal(restored.state.sent.length, 1);
});
test('unconfirmed Discord receipt cannot discard an expense', async () => {
  const fake = new FakeRelay(), client = fake.client(); await client.sync(); await client.queue(input); fake.badReceipt = true;
  await assert.rejects(client.sync(), /did not confirm receipt/); assert.equal(client.state.pending.length, 1); assert.equal(client.state.sent.length, 0);
});
test('bootstrap packet cannot belong to another invitation', async () => {
  const fake = new FakeRelay(); fake.wrongId = true;
  await assert.rejects(fake.client().sync(), /could not be verified/);
});
test('attachment restrictions and fetch options keep credentials off third-party requests', async () => {
  const fake = new FakeRelay(), client = fake.client(); fake.badAttachment = true;
  await assert.rejects(client.sync(), /attachment is invalid/);
  assert.ok(fake.calls.every(call => !call.url.includes('evil.example')));
  assert.ok(fake.calls.every(({ options }) => options.credentials === 'omit' && options.redirect === 'error' && !options.headers));
});
test('rate limiting backs off without clearing queue', async () => {
  let now = 1000; const fake = new FakeRelay(), client = fake.client(undefined, { clock: () => now }); await client.sync(); await client.queue(input);
  fake.rateLimit = true; await assert.rejects(client.sync(), error => error.kind === 'waiting'); const calls = fake.calls.length;
  await assert.rejects(client.sync()); assert.equal(fake.calls.length, calls); assert.equal(client.state.pending.length, 1);
  now += 2100; fake.rateLimit = false; await client.sync(); assert.equal(client.state.pending.length, 0);
});
test('expired invitations never send or queue but preserve cached pending data', async () => {
  const fake = new FakeRelay(), client = fake.client(); await client.sync(); await client.queue(input);
  client.invite.expires = 1; const calls = fake.calls.length;
  await assert.rejects(client.sync(), error => error.kind === 'expired'); await assert.rejects(client.queue(input));
  assert.equal(fake.calls.length, calls); assert.equal(client.state.pending.length, 1);
});

test('two tabs retain both queued expenses and serialize Discord deliveries', async () => {
  const fake = new FakeRelay(), storage = memoryStorage();
  const locks = globalThis.navigator?.locks ?? fake.locks;
  const first = fake.client(storage, { locks }), second = fake.client(storage, { locks });
  await first.sync(); await second.load();
  const [a, b] = await Promise.all([first.queue({ ...input, note: 'First tab' }), second.queue({ ...input, note: 'Second tab' })]);
  const restored = await fake.client(storage).load();
  assert.deepEqual(new Set(restored.state.pending.map(row => row.id)), new Set([a.id, b.id]));
  await Promise.all([first.sync(), second.sync()]);
  assert.equal((await fake.client(storage).load()).state.pending.length, 0);
  assert.deepEqual((fake.receive(), fake.saved), new Set([a.id, b.id]));
});
test('unsupported coordination cannot send or silently replace the queue', async () => {
  const fake = new FakeRelay(), client = fake.client(undefined, { locks: null });
  await assert.rejects(client.sync(), /Update Safari/);
  await assert.rejects(client.queue(input), /Update Safari/);
  assert.equal(fake.calls.length, 0);
  assert.equal(client.state.pending.length, 0);
});
