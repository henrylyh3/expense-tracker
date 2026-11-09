import 'dart:convert';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/sharing/discord_api.dart';
import 'package:expense_tracker/core/sharing/sharing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_discord.dart';

// No live Discord credentials are used.
void main() {
  late AppDatabase hostDb, guestDb;
  late SharingService host, guest;
  late MemorySecrets hostSecrets, guestSecrets;
  late FakeDiscord api;
  late String code, id;
  setUp(() async {
    hostDb = AppDatabase.forTesting(NativeDatabase.memory());
    guestDb = AppDatabase.forTesting(NativeDatabase.memory());
    await hostDb.initialize();
    await guestDb.initialize();
    api = FakeDiscord();
    hostSecrets = MemorySecrets();
    guestSecrets = MemorySecrets();
    host = SharingService(hostDb, discordApi: api, relaySecrets: hostSecrets);
    guest = SharingService(
      guestDb,
      discordApi: api,
      relaySecrets: guestSecrets,
    );
    await host.configureDiscord('123456789012345', 'host-bot-secret');
    code = await host.inviteDiscord('personal', 'Alice');
    final invitation =
        jsonDecode(utf8.decode(base64Url.decode(code.substring(13)))) as Map;
    id = invitation['id'] as String;
  });
  tearDown(() async {
    await hostDb.close();
    await guestDb.close();
  });

  Future<void> join() async {
    await guest.join(code);
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    await host.pollDiscord();
    await guest.sync(id);
  }

  Future<void> add() => guest.queue(id, {
    'category': 'seed-food',
    'currency_id': 'MYR',
    'amount': '12.50',
    'date': '2026-11-09',
    'note': 'Lunch',
  });
  Future<int> count() async =>
      (await hostDb
              .customSelect('SELECT count(*) AS n FROM transactions')
              .getSingle())
          .read<int>('n');

  test(
    'host sync reports real batch progress and clears it after completion',
    () async {
      await guest.join(code);
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      final progress = <DiscordSyncProgress>[];
      final subscription = host.discordProgress.listen(progress.add);
      addTearDown(subscription.cancel);
      await host.pollDiscord();
      await Future<void>.delayed(Duration.zero);
    expect(progress.first.stage, 'Connecting to Discord');
    expect(progress.map((p) => p.stage), contains('Fetching Discord requests'));
      expect(progress.last.stage, 'idle');
      final batches = progress.where((p) => p.total != null).toList();
      expect(batches, isNotEmpty);
      expect(batches.last.completed, batches.last.total);
    },
  );
  test('host sync clears progress on an acknowledgement error', () async {
    await guest.join(code);
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    api.failReply = true;
    final progress = <DiscordSyncProgress>[];
    final subscription = host.discordProgress.listen(progress.add);
    addTearDown(subscription.cancel);
    await expectLater(host.pollDiscord(), throwsA(isA<LedgerException>()));
    await Future<void>.delayed(Duration.zero);
    expect(progress.last.stage, 'idle');
    api.failReply = false;
    await host.pollDiscord();
    await guest.sync(id);
  });

  test(
    'one setup creates separate invitations without sharing bot credentials',
    () async {
      final second = await host.inviteDiscord('personal', 'Bob');
      expect(second, isNot(code));
      expect(api.webhooks.length, 2);
      expect(
        utf8.decode(base64Url.decode(code.substring(13))),
        isNot(contains('host-bot-secret')),
      );
      expect(await guest.discordSettings(), isNull);
    },
  );
  test(
    'guest joins, reads snapshot, sends expense and waits for confirmed insert',
    () async {
      await join();
      await add();
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      expect(await count(), 0);
      expect(
        (await guestDb.customSelect('SELECT * FROM shared_pending').get())
            .length,
        1,
      );
      await host.pollDiscord();
      expect(await count(), 1);
      await guest.sync(id);
      expect(
        await guestDb.customSelect('SELECT * FROM shared_pending').get(),
        isEmpty,
      );
      final saved = await hostDb
          .customSelect(
            'SELECT trip_id,amount_myr_minor,note FROM transactions',
          )
          .getSingle();
      expect(saved.read<String>('trip_id'), 'personal');
      expect(saved.read<int>('amount_myr_minor'), 1250);
      expect(saved.read<String>('note'), 'Lunch');
      expect(jsonEncode(api.inbox), isNot(contains('Lunch')));
    },
  );
  test(
    'lost acknowledgement retries and host restart do not duplicate expenses',
    () async {
      await join();
      await add();
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      api.failReply = true;
      await expectLater(host.pollDiscord(), throwsA(isA<LedgerException>()));
      expect(await count(), 1);
      host = SharingService(hostDb, discordApi: api, relaySecrets: hostSecrets);
      await host.pollDiscord();
      await guest.sync(id);
      expect(await count(), 1);
    },
  );
  test(
    'guest restart retains sent request and does not repost while waiting',
    () async {
      await join();
      await add();
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      final before = api.inbox.length;
      guest = SharingService(
        guestDb,
        discordApi: api,
        relaySecrets: guestSecrets,
      );
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      expect(api.inbox.length, before);
      await host.pollDiscord();
      await guest.sync(id);
      expect(await count(), 1);
    },
  );
  test(
    'revocation blocks queued writes immediately even when webhook deletion is offline',
    () async {
      await join();
      await add();
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      api.failDelete = true;
      await host.revoke(id);
      await host.pollDiscord();
      expect(await count(), 0);
      expect(hostSecrets.values['revocations'], isNotNull);
      api.failDelete = false;
      await host.retryDiscordRevocations();
      await expectLater(
        guest.sync(id),
        throwsA(
          isA<LedgerException>().having(
            (e) => e.message,
            'message',
            contains('no longer available'),
          ),
        ),
      );
      expect(
        await guestDb.customSelect('SELECT * FROM shared_pending').get(),
        hasLength(1),
      );
    },
  );
  test('forged trip or guest identifiers cannot insert records', () async {
    await join();
    await add();
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    (api.inbox.last['payload'] as Map)['id'] = 'forged-guest';
    await host.pollDiscord();
    expect(await count(), 0);
    final row = await hostDb
        .customSelect('SELECT * FROM shared_sessions')
        .getSingle();
    final connection = DiscordConnection.decode(row.read<String>('endpoint'));
    final forged = await host.cipher.seal(
      {
        'action': 'add',
        'request': id,
        'trip': 'another-trip',
        'submission': id,
        'expense': {},
      },
      row.read<String>('secret'),
      'discord-request:$id:${connection.trip}',
    );
    await api.post(connection.webhook, {
      'direction': 'request',
      'id': id,
      ...forged,
    });
    await host.pollDiscord();
    expect(await count(), 0);
  });
  test(
    'poll pages through more than 100 messages without dropping queued requests',
    () async {
      await join();
      for (var n = 0; n < 120; n++) {
        api.inbox.add({'id': '${++api.next}', 'webhook_id': 'unrelated'});
      }
      await add();
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      await host.pollDiscord();
      await guest.sync(id);
      expect(await count(), 1);
    },
  );
  test(
    'connection cannot change channel or be cleared while invitations exist',
    () async {
      await expectLater(
        host.configureDiscord('987654321098765', 'new-token'),
        throwsA(isA<LedgerException>()),
      );
      await expectLater(host.clearDiscord(), throwsA(isA<LedgerException>()));
      await host.revoke(id);
      await host.clearDiscord();
      expect(await host.discordSettings(), isNull);
    },
  );
  test(
    'webhook validation rejects arbitrary hosts, redirects and embedded credentials',
    () {
      for (final url in [
        'http://discord.com/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz',
        'https://evil.example/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz',
        'https://discord.com@evil.example/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz',
        'https://discord.com/api/webhooks/123456789012345/abcdefghijklmnopqrstuvwxyz?redirect=1',
      ]) {
        expect(
          () => DiscordConnection.validateWebhook(url),
          throwsA(isA<LedgerException>()),
        );
      }
    },
  );
  test('invalid expense is rejected without losing the local queue', () async {
    await join();
    await add();
    await guestDb.customStatement("UPDATE shared_pending SET payload = ?", [
      jsonEncode({
        'category': 'does-not-exist',
        'currency': 'MYR',
        'amount': '12.50',
        'rate': '1',
        'date': '2026-11-09',
        'note': null,
      }),
    ]);
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    await host.pollDiscord();
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    expect(await count(), 0);
    expect(
      await guestDb.customSelect('SELECT * FROM shared_pending').get(),
      hasLength(1),
    );
  });
  test(
    'hidden message contents stop cursor advancement until permissions are fixed',
    () async {
      await guest.join(code);
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      final message = api.inbox.last;
      final encrypted = message.remove('payload');
      message['content'] = '';
      message['attachments'] = <Object>[];
      await expectLater(
        host.pollDiscord(),
        throwsA(
          isA<LedgerException>().having(
            (e) => e.message,
            'message',
            contains('Message Content Intent'),
          ),
        ),
      );
      message['payload'] = encrypted;
      await host.pollDiscord();
      await guest.sync(id);
      final cache =
          (await guestDb
                  .customSelect('SELECT cache FROM shared_sessions')
                  .getSingle())
              .readNullable<String>('cache');
      expect(cache, isNotNull);
    },
  );
}
