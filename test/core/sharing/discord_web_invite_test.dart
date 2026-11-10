import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/sharing/discord_api.dart';
import 'package:expense_tracker/core/sharing/sharing_cipher.dart';
import 'package:expense_tracker/core/sharing/sharing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_discord.dart';

void main() {
  late AppDatabase hostDb, guestDb;
  late SharingService host, guest;
  late FakeDiscord api;
  late DateTime hostNow, guestNow;
  setUp(() async {
    hostNow = guestNow = DateTime.utc(2026, 11, 10);
    hostDb = AppDatabase.forTesting(NativeDatabase.memory());
    guestDb = AppDatabase.forTesting(NativeDatabase.memory());
    await hostDb.initialize();
    await guestDb.initialize();
    api = FakeDiscord(clock: () => hostNow);
    host = SharingService(
      hostDb,
      discordApi: api,
      relaySecrets: MemorySecrets(),
      clock: () => hostNow,
    );
    guest = SharingService(
      guestDb,
      discordApi: api,
      relaySecrets: MemorySecrets(),
      clock: () => guestNow,
    );
    await host.configureDiscord('123456789012345', 'host-only-secret');
  });
  tearDown(() async {
    await host.dispose();
    await guest.dispose();
    await hostDb.close();
    await guestDb.close();
  });
  Map<String, dynamic> decode(String code) =>
      jsonDecode(utf8.decode(base64Url.decode(code.substring(13))))
          as Map<String, dynamic>;
  test(
    'web link keeps credentials in fragment and persists host expiry',
    () async {
      final link = Uri.parse(
        await host.inviteDiscordWeb(
          'personal',
          'Alice',
          Uri.parse('https://guest.example/'),
        ),
      );
      expect(link.query, isEmpty);
      expect(link.fragment, startsWith('invite=expense-trip:'));
      final code = Uri.splitQueryString(link.fragment)['invite']!;
      final data = decode(code);
      expect(jsonEncode(data), isNot(contains('host-only-secret')));
      final endpoint = DiscordConnection.decode(data['endpoint'] as String);
      expect(endpoint.expiresAt, hostNow.add(const Duration(days: 7)));
      final row = await hostDb
          .customSelect('SELECT endpoint FROM shared_sessions')
          .getSingle();
      expect(row.read<String>('endpoint'), data['endpoint']);
      expect(link.toString().length, lessThan(4096));
      final packet = await api.packet(
        await api.get(endpoint.webhook, data['bootstrap'] as String),
      );
      expect(packet!['direction'], 'invite');
      final view = await SharingCipher().open(
        packet,
        data['key'] as String,
        'discord-invite:${data['id']}:personal',
      );
      expect((view['snapshot'] as Map)['categories'], isNotEmpty);
      expect(jsonEncode(packet), isNot(contains('seed-food')));
      await guest.join(code);
    },
  );
  test(
    'host rejects expired requests even when guest removes expiry',
    () async {
      final code = await host.inviteDiscord(
        'personal',
        'Alice',
        validFor: const Duration(minutes: 1),
      );
      final data = decode(code),
          connection = DiscordConnection.decode(
            decode(code)['endpoint'] as String,
          );
      data['endpoint'] = DiscordConnection(
        connection.webhook,
        connection.trip,
      ).encode();
      final forged =
          'expense-trip:${base64UrlEncode(utf8.encode(jsonEncode(data)))}';
      final id = data['id'] as String;
      await guest.join(forged);
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      await host.pollDiscord();
      await guest.sync(id);
      await guest.queue(id, {
        'category': 'seed-food',
        'currency_id': 'MYR',
        'amount': '12.50',
        'date': '2026-11-10',
      });
      hostNow = hostNow.add(const Duration(minutes: 2));
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      await host.pollDiscord();
      await expectLater(
        guest.sync(id),
        throwsA(
          isA<LedgerException>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );
      final count = await hostDb
          .customSelect('SELECT count(*) AS n FROM transactions')
          .getSingle();
      expect(count.read<int>('n'), 0);
      await host.revoke(id);
      expect(api.webhooks, isEmpty);
    },
  );
  test(
    'expired links cannot join; invalid TTL and page create no webhooks',
    () async {
      for (final page in [
        'http://guest.example/',
        'https://guest.example/?tracking=1',
        'https://user@guest.example/',
        'https://guest.example/#invite=x',
      ]) {
        await expectLater(
          host.inviteDiscordWeb('personal', 'Alice', Uri.parse(page)),
          throwsA(isA<LedgerException>()),
        );
      }
      await expectLater(
        host.inviteDiscord('personal', 'Alice', validFor: Duration.zero),
        throwsA(isA<LedgerException>()),
      );
      expect(api.webhooks, isEmpty);
      final code = await host.inviteDiscord(
        'personal',
        'Alice',
        validFor: const Duration(minutes: 1),
      );
      guestNow = guestNow.add(const Duration(minutes: 1));
      await expectLater(
        guest.join(code),
        throwsA(
          isA<LedgerException>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    },
  );
  test(
    'valid Discord deliveries import once even when host opens after expiry',
    () async {
      final code = await host.inviteDiscord(
        'personal',
        'Alice',
        validFor: const Duration(minutes: 1),
      );
      final data = decode(code), id = data['id'] as String;
      await guest.join(code);
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      await host.pollDiscord();
      await guest.sync(id);
      await guest.queue(id, {
        'category': 'seed-food',
        'currency_id': 'MYR',
        'amount': '12.50',
        'date': '2026-11-10',
      });
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
      final connection = DiscordConnection.decode(data['endpoint'] as String);
      await api.post(
        connection.webhook,
        Map<String, Object?>.from(api.inbox.last['payload'] as Map),
      );
      hostNow = hostNow.add(const Duration(days: 1));
      await host.pollDiscord();
      final count = await hostDb
          .customSelect('SELECT count(*) AS n FROM transactions')
          .getSingle();
      expect(count.read<int>('n'), 1);
    },
  );
  test('editing an old message after expiry cannot extend access', () async {
    final code = await host.inviteDiscord(
      'personal',
      'Alice',
      validFor: const Duration(minutes: 1),
    );
    final id = decode(code)['id'] as String;
    await guest.join(code);
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    await host.pollDiscord();
    await guest.sync(id);
    await guest.queue(id, {
      'category': 'seed-food',
      'currency_id': 'MYR',
      'amount': '12.50',
      'date': '2026-11-10',
    });
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    hostNow = hostNow.add(const Duration(minutes: 2));
    api.inbox.last['edited_timestamp'] = hostNow.toIso8601String();
    await host.pollDiscord();
    await expectLater(
      guest.sync(id),
      throwsA(
        isA<LedgerException>().having(
          (e) => e.message,
          'message',
          contains('expired'),
        ),
      ),
    );
    final count = await hostDb
        .customSelect('SELECT count(*) AS n FROM transactions')
        .getSingle();
    expect(count.read<int>('n'), 0);
  });
  test('failed invitation upload revokes its session and webhook', () async {
    api.failPost = true;
    await expectLater(
      host.inviteDiscordWeb(
        'personal',
        'Alice',
        Uri.parse('https://guest.example/'),
      ),
      throwsA(isA<LedgerException>()),
    );
    expect(api.webhooks, isEmpty);
    expect(
      await hostDb.customSelect('SELECT id FROM shared_sessions').get(),
      isEmpty,
    );
  });
  test(
    'one-way browser expenses import without sending host acknowledgements',
    () async {
      final link = Uri.parse(
        await host.inviteDiscordWeb(
          'personal',
          'Alice',
          Uri.parse('https://guest.example/'),
        ),
      );
      final data = decode(Uri.splitQueryString(link.fragment)['invite']!),
          id = data['id'] as String;
      final connection = DiscordConnection.decode(data['endpoint'] as String);
      for (var n = 1; n <= 3; n++) {
        final encrypted = await SharingCipher().seal(
          {
            'action': 'add',
            'reply': false,
            'trip': 'personal',
            'request': '12345678-1234-4234-8234-12345678910$n',
            'submission': '12345678-1234-4234-8234-12345678920$n',
            'expense': {
              'category': 'seed-food',
              'currency': 'MYR',
              'amount': n == 1 ? '-1' : '12.50',
              'rate': '1',
              'date': '2026-11-10',
            },
          },
          data['key'] as String,
          'discord-request:$id:personal',
        );
        await api.post(connection.webhook, {
          'direction': 'request',
          'id': id,
          ...encrypted,
        });
      }
      api.failReply = true;
      await host.pollDiscord();
      final count = await hostDb
          .customSelect('SELECT count(*) AS n FROM transactions')
          .getSingle();
      expect(count.read<int>('n'), 2);
      expect(api.failReply, isTrue);
      expect(
        api.inbox
            .skip(1)
            .every(
              (message) =>
                  (message['payload'] as Map)['direction'] == 'request',
            ),
        isTrue,
      );
    },
  );
  test('a delayed read cannot expose a fresh snapshot after expiry', () async {
    final code = await host.inviteDiscord(
      'personal',
      'Alice',
      validFor: const Duration(minutes: 1),
    );
    final id = decode(code)['id'] as String;
    await guest.join(code);
    await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
    final data = decode(code);
    final request = await SharingCipher().open(
      (await api.packet(api.inbox.last))!,
      data['key'] as String,
      'discord-request:$id:personal',
    );
    hostNow = hostNow.add(const Duration(minutes: 2));
    await host.pollDiscord();
    await expectLater(
      guest.sync(id),
      throwsA(
        isA<LedgerException>().having(
          (e) => e.message,
          'message',
          contains('expired'),
        ),
      ),
    );
    final response = await SharingCipher().open(
      (await api.packet(api.inbox.last))!,
      data['key'] as String,
      'discord-response:$id:${request['request']}',
    );
    expect(response.containsKey('snapshot'), isFalse);
    expect(response['error'], contains('expired'));
  });
  test('WebCrypto packet decrypts with native SharingCipher', () async {
    final fixture =
        jsonDecode(
              await File('guest-web/test/webcrypto-vector.json').readAsString(),
            )
            as Map<String, dynamic>;
    final plain = await SharingCipher().open(
      fixture['packet'] as Map<String, dynamic>,
      fixture['key'] as String,
      fixture['context'] as String,
    );
    expect(plain, fixture['plain']);
  });
}
