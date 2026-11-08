import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/sharing/sharing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android encrypted host and guest sync commits one expense', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final hostDb = AppDatabase.forTesting(NativeDatabase.memory());
      final guestDb = AppDatabase.forTesting(NativeDatabase.memory());
      final host = SharingService(hostDb);
      final guest = SharingService(guestDb);
      try {
        await hostDb.initialize();
        await guestDb.initialize();
        await host.startHost(
          address: InternetAddress.loopbackIPv4,
          bindPort: 0,
        );
        final invite = await host.invite(
          'personal',
          'Android guest',
          'http://127.0.0.1:${host.port}',
        );
        await guest.join(invite);
        final session =
            (await guestDb
                    .customSelect('SELECT id FROM shared_sessions')
                    .getSingle())
                .read<String>('id');
        await guest.sync(session);
        await guest.queue(session, {
          'category': 'seed-food',
          'currency_id': 'MYR',
          'amount': '18.50',
          'date': '2026-11-08',
          'note': 'Android sharing smoke test',
        });
        await guest.sync(session);
        await guest.sync(session);
        final row = await hostDb
            .customSelect('SELECT amount_myr_minor FROM transactions')
            .getSingle();
        expect(row.read<int>('amount_myr_minor'), 1850);
        expect(
          await guestDb.customSelect('SELECT * FROM shared_pending').get(),
          isEmpty,
        );
      } finally {
        await host.stopHost();
        await guest.stopHost();
        await guestDb.close();
        await hostDb.close();
      }
    });
  });
}
