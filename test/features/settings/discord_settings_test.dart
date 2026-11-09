import 'dart:async';
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/providers/trip_provider.dart';
import 'package:expense_tracker/core/sharing/sharing_service.dart';
import 'package:expense_tracker/features/sharing/presentation/discord_settings.dart';
import 'package:expense_tracker/features/sharing/presentation/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_discord.dart';

class _HeldDiscord extends FakeDiscord {
  Completer<void>? gate;
  @override
  Future<List<Map<String, dynamic>>> messages(
    String channel,
    String token,
    String? after,
  ) async {
    if (gate != null) await gate!.future;
    return super.messages(channel, token, after);
  }
}

void main() {
  testWidgets(
    'foreground sync status appears while fetching and clears after sync',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final api = _HeldDiscord();
      final service = SharingService(
        db,
        discordApi: api,
        relaySecrets: MemorySecrets(),
      );
      addTearDown(service.dispose);
      await service.configureDiscord('123456789012345', 'private-bot-token');
      await service.inviteDiscord('personal', 'Guest');
      api.gate = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharingServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: const Scaffold(body: Text('Ledger')),
            builder: (_, child) =>
                DiscordSyncOnOpen(ready: true, busy: false, child: child!),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Fetching Discord requests'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Ledger'), findsOneWidget);
      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'internet setup saves protected host details and enables internet invitations',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final secrets = MemorySecrets();
      final service = SharingService(
        db,
        discordApi: FakeDiscord(),
        relaySecrets: secrets,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharingServiceProvider.overrideWithValue(service),
            activeTripProvider.overrideWith((ref) => Stream.value('personal')),
            tripsProvider.overrideWith(
              (ref) => Stream.value([(id: 'personal', name: 'Personal')]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: SharingScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invite guest over internet'), findsNothing);
      await tester.tap(find.text('Configure internet sharing'));
      await tester.pumpAndSettle();
      expect(find.byType(DiscordSettingsDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '123456789012345');
      await tester.enterText(find.byType(TextField).at(1), 'private-bot-token');
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );
      await tester.tap(find.text('Verify and save'));
      await tester.pumpAndSettle();
      expect(find.text('Invite guest over internet'), findsOneWidget);
      expect(find.textContaining('private-bot-token'), findsNothing);
      expect((await service.discordSettings())!['channel'], '123456789012345');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
