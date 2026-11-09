import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/backup/backup_service.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/sharing/sharing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase hostDb;
  late AppDatabase guestDb;
  late SharingService host;
  late SharingService guest;
  late Map<String, dynamic> invitation;
  late Directory guestDirectory;
  setUp(() async {
    hostDb = AppDatabase.forTesting(NativeDatabase.memory());
    guestDirectory = await Directory.systemTemp.createTemp(
      'sharing-guest-test-',
    );
    guestDb = AppDatabase.forTesting(
      NativeDatabase(File('${guestDirectory.path}/guest.sqlite')),
    );
    await hostDb.initialize();
    await guestDb.initialize();
    host = SharingService(hostDb);
    guest = SharingService(guestDb);
    await host.startHost(address: InternetAddress.loopbackIPv4, bindPort: 0);
    final code = await host.invite(
      'personal',
      'Henry guest',
      'http://127.0.0.1:${host.port}',
    );
    invitation =
        jsonDecode(
              utf8.decode(
                base64Url.decode(code.substring('expense-trip:'.length)),
              ),
            )
            as Map<String, dynamic>;
    await guest.join(code);
  });
  tearDown(() async {
    await host.stopHost();
    await guest.stopHost();
    await guestDb.close();
    await hostDb.close();
    await guestDirectory.delete(recursive: true);
  });

  test(
    'guest queues offline, retries after restart and host remains authoritative',
    () async {
      final id = invitation['id'] as String;
      await guest.sync(id);
      await guest.queue(id, {
        'category': 'seed-food',
        'currency_id': 'MYR',
        'amount': '12.50',
        'date': '2026-11-08',
        'note': 'Shared meal 🍜',
      });
      final port = host.port;
      await host.stopHost();
      await expectLater(guest.sync(id), throwsException);
      expect(
        (await guestDb
                .customSelect('SELECT count(*) AS n FROM shared_pending')
                .getSingle())
            .read<int>('n'),
        1,
      );
      expect(
        await guestDb.customSelect('SELECT * FROM transactions').get(),
        isEmpty,
      );
      await host.startHost(
        address: InternetAddress.loopbackIPv4,
        bindPort: port,
      );
      await guestDb.close();
      guestDb = AppDatabase.forTesting(
        NativeDatabase(File('${guestDirectory.path}/guest.sqlite')),
      );
      await guestDb.initialize();
      guest = SharingService(guestDb);
      await guest.sync(id);
      final saved = await hostDb
          .customSelect('SELECT amount_myr_minor, note FROM transactions')
          .getSingle();
      expect(saved.read<int>('amount_myr_minor'), 1250);
      expect(saved.read<String>('note'), 'Shared meal 🍜');
      expect(
        await guestDb.customSelect('SELECT * FROM shared_pending').get(),
        isEmpty,
      );
      await guest.sync(id);
      expect(
        (await hostDb
                .customSelect('SELECT count(*) AS n FROM transactions')
                .getSingle())
            .read<int>('n'),
        1,
      );
      final exported = utf8.decode(await BackupService(hostDb).exportBytes());
      expect(exported.contains(invitation['key'] as String), isFalse);
    },
  );

  test(
    'replayed expense is committed once and invitation revocation blocks sync',
    () async {
      final id = invitation['id'] as String;
      final submission = const Uuid().v4();
      Future<int> submit(String requestId, {String? secret}) async {
        final packet = await guest.cipher.seal(
          {
            'action': 'add',
            'request': requestId,
            'submission': submission,
            'expense': {
              'category': 'seed-food',
              'currency': 'MYR',
              'amount': '5.00',
              'rate': '1',
              'date': '2026-11-08',
              'note': null,
            },
          },
          secret ?? invitation['key'] as String,
          'request:$id',
        );
        final client = HttpClient();
        try {
          final req = await client.postUrl(
            Uri.parse('http://127.0.0.1:${host.port}/sync'),
          );
          req.write(jsonEncode({'id': id, ...packet}));
          final res = await req.close();
          await res.drain<void>();
          return res.statusCode;
        } finally {
          client.close(force: true);
        }
      }

      expect(await submit(const Uuid().v4()), 200);
      expect(await submit(const Uuid().v4()), 200);
      expect(
        (await hostDb
                .customSelect('SELECT count(*) AS n FROM transactions')
                .getSingle())
            .read<int>('n'),
        1,
      );
      expect(
        await submit(const Uuid().v4(), secret: await guest.cipher.newKey()),
        403,
      );
      await hostDb.customUpdate(
        'DELETE FROM transactions',
        updates: {hostDb.transactions},
      );
      expect(await submit(const Uuid().v4()), 200);
      expect(
        await hostDb.customSelect('SELECT * FROM transactions').get(),
        isEmpty,
      );
      await host.revoke(id);
      await expectLater(guest.sync(id), throwsException);
    },
  );

  test('snapshot includes the selected named trip currency', () async {
    await hostDb.customStatement(
      "INSERT INTO currencies VALUES ('THB','Thai baht','฿',2,'0.12',1,0,0)",
    );
    await hostDb.customStatement(
      "INSERT INTO currency_rates VALUES ('thb-2026','THB','THB 2026','0.13',1)",
    );
    await hostDb.customStatement(
      "INSERT INTO trip_rates VALUES ('personal','THB','0.13','THB 2026','thb-2026')",
    );
    await hostDb.customStatement(
      "INSERT INTO app_settings VALUES ('trip_currency:personal','THB')",
    );
    await guest.sync(invitation['id'] as String);
    final cache =
        (await guestDb
                .customSelect('SELECT cache FROM shared_sessions')
                .getSingle())
            .read<String>('cache');
    final snapshot = jsonDecode(cache) as Map;
    expect(snapshot['default_currency'], 'thb-2026');
    expect(
      (snapshot['currencies'] as List)
          .where((c) => c['id'] == 'thb-2026')
          .single['rate'],
      '0.13',
    );
  });

  test(
    'snapshot exposes only the invited trip and reset revokes access',
    () async {
      await hostDb.customStatement(
        "INSERT INTO trips VALUES ('private','Private trip')",
      );
      await hostDb.customStatement(
        "INSERT INTO transactions (id, category_id, type, amount_minor, currency_code, exchange_rate_snapshot, amount_myr_minor, transaction_date, note, created_at_utc, updated_at_utc, trip_id) VALUES ('12345678-1234-4234-8234-123456789abc','seed-food','expense',900,'MYR','1',900,'2026-11-08','private note',0,0,'private')",
      );
      await guest.sync(invitation['id'] as String);
      final cache =
          (await guestDb
                  .customSelect('SELECT cache FROM shared_sessions')
                  .getSingle())
              .read<String>('cache');
      expect(cache.contains('private note'), isFalse);
      expect((jsonDecode(cache) as Map)['total_myr_minor'], '0');
      await hostDb.resetLedger();
      await expectLater(
        guest.sync(invitation['id'] as String),
        throwsException,
      );
      expect(
        await hostDb.customSelect('SELECT * FROM shared_sessions').get(),
        isEmpty,
      );
    },
  );
}
