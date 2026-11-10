import 'dart:convert';
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/app_database.dart';
import 'package:expense_tracker/core/providers/trip_provider.dart';
import 'package:expense_tracker/core/sharing/discord_api.dart';
import 'package:expense_tracker/core/sharing/guest_web.dart';
import 'package:expense_tracker/core/sharing/sharing_service.dart';
import 'package:expense_tracker/features/sharing/presentation/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_discord.dart';

// Run with --dart-define=GUEST_WEB_URL=https://guest.example/ before deployment.
void main() {
  testWidgets('host creates a web link with the selected expiry', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.initialize();
    addTearDown(db.close);
    final now = DateTime.utc(2026, 11, 10);
    final service = SharingService(
      db,
      discordApi: FakeDiscord(),
      relaySecrets: MemorySecrets(),
      clock: () => now,
    );
    addTearDown(service.dispose);
    await service.configureDiscord('123456789012345', 'host-only-secret');
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
    final button = find.widgetWithText(
      OutlinedButton,
      'Invite guest by web link',
    );
    if (guestWebUrl.isEmpty) {
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      return;
    }
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Invite a web guest'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Guest name'),
      'Alice',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('24 hours').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      await tester.tap(find.text('Create link'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Expires after 24 hours'), findsOneWidget);
    final link = Uri.parse(
      tester.widget<SelectableText>(find.byType(SelectableText)).data!,
    );
    final code = Uri.splitQueryString(link.fragment)['invite']!;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(code.substring(13)))) as Map;
    expect(
      DiscordConnection.decode(payload['endpoint'] as String).expiresAt,
      now.add(const Duration(days: 1)),
    );
    expect(link.scheme, 'https');
    expect(link.query, isEmpty);
    expect(find.textContaining('host-only-secret'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
