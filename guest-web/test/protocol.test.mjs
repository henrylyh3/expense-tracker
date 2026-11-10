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
test('waiting request survives reload without repost; only authenticated acknowledgement dequeues', async () => {
  const fake = new FakeRelay(), storage = memoryStorage(), client = fake.client(storage);
  await client.sync(); await client.queue(input); fake.waiting = true;
  await assert.rejects(client.sync(), error => error.kind === 'waiting');
  const id = client.state.pending[0].id, posts = fake.posts;
  assert.ok(!storage.getItem(client.slot).includes('Private lunch note'));
  const restored = await fake.client(storage).load();
  await assert.rejects(restored.sync(), error => error.kind === 'waiting'); assert.equal(fake.posts, posts);
  fake.waiting = false; fake.wrongId = true;
  await assert.rejects(restored.sync(), /different invitation/); assert.equal(restored.state.pending.length, 1);
  fake.wrongId = false; await restored.sync();
  assert.equal(fake.posts, posts); assert.equal(restored.state.pending.length, 0); assert.ok(fake.saved.has(id));
});
test('missing relay message retries with stable submission id', async () => {
  const fake = new FakeRelay(), client = fake.client(); await client.sync(); await client.queue(input); fake.waiting = true;
  await assert.rejects(client.sync()); const id = client.state.pending[0].id; fake.messages.clear();
  await assert.rejects(client.sync(), /message was removed/); fake.waiting = false; await client.sync();
  assert.ok(fake.saved.has(id)); assert.equal(fake.saved.size, 1);
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
