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
    api = FakeDiscord();
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
      await expectLater(guest.sync(id), throwsA(isA<LedgerException>()));
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
