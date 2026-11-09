import 'dart:async';

import 'package:expense_tracker/core/updates/update_service.dart';
import 'package:expense_tracker/features/settings/presentation/update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final release = UpdateRelease(
  version: '0.4.3',
  versionCode: 2012,
  size: 1024,
  sha256: 'a' * 64,
  url: Uri.parse('https://github.com/test/update.apk'),
  notes: 'New version. ' * 100,
);

class _Updates extends UpdateService {
  int checks = 0;
  int installs = 0;
  int permissions = 0;
  bool allowed = true;
  bool offline = false;
  bool holdDownload = false;
  Completer<String>? pending;
  @override
  Future<UpdateRelease?> check() async {
    checks++;
    if (offline) throw Exception('offline');
    return release;
  }

  @override
  Future<String> download(
    UpdateRelease update,
    void Function(int, int) progress,
  ) async {
    progress(512, 1024);
    if (holdDownload) {
      pending = Completer<String>();
      return pending!.future;
    }
    return '/verified/update.apk';
  }

  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> requestPermission() async {
    permissions++;
  }

  @override
  Future<void> install(UpdateRelease release, String path) async {
    installs++;
  }

  @override
  void cancel() {
    pending?.completeError(UpdateCancelled());
    pending = null;
  }
}

Widget _app(
  _Updates service, {
  bool ready = true,
  bool canPrompt = true,
  DateTime Function()? clock,
}) {
  final navigator = GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      updateServiceProvider.overrideWithValue(service),
      updateSupportedProvider.overrideWithValue(true),
      if (clock != null) updateClockProvider.overrideWithValue(clock),
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('Ledger')),
      builder: (_, child) => UpdateCheckOnOpen(
        ready: ready,
        busy: false,
        canPrompt: () => canPrompt,
        navigatorContext: () => navigator.currentState?.overlay?.context,
        child: child!,
      ),
    ),
  );
}

void main() {
  testWidgets('retains an available update while away from Home', (
    tester,
  ) async {
    final service = _Updates();
    await tester.pumpWidget(_app(service, canPrompt: false));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    expect(service.checks, 1);
  });
  testWidgets('resuming retries an earlier failed check after five minutes', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 9);
    final service = _Updates()..offline = true;
    await tester.pumpWidget(_app(service, clock: () => now));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    service.offline = false;
    now = now.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.checks, 2);
    expect(find.text('Update available'), findsOneWidget);
  });
  testWidgets('Settings shows a failed check and can retry successfully', (
    tester,
  ) async {
    final service = _Updates()..offline = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateServiceProvider.overrideWithValue(service),
          updateSupportedProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: Scaffold(body: CheckUpdatesButton())),
      ),
    );
    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Could not check for updates'), findsOneWidget);
    service.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    expect(service.checks, 2);
  });
  testWidgets('startup checks once and Later keeps the ledger open', (
    tester,
  ) async {
    final service = _Updates();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger'), findsOneWidget);
    expect(service.checks, 1);
    expect(service.installs, 0);
  });
  testWidgets('failed startup and offline checks never block the ledger', (
    tester,
  ) async {
    final service = _Updates();
    await tester.pumpWidget(_app(service, ready: false));
    await tester.pumpAndSettle();
    expect(service.checks, 0);
    service.offline = true;
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(service.checks, 1);
    expect(find.text('Update available'), findsNothing);
    expect(find.text('Ledger'), findsOneWidget);
  });
  testWidgets(
    'Update now downloads then resumes installation after permission',
    (tester) async {
      final service = _Updates()..allowed = false;
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(service.permissions, 1);
      expect(service.installs, 0);
      service.allowed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.installs, 1);
    },
  );
  testWidgets('download can be cancelled without launching the installer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Updates()..holdDownload = true;
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(find.text('Downloading… 50%').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel download'));
    await tester.pumpAndSettle();
    expect(
      find.text('Download cancelled. Your current app is unchanged.'),
      findsOneWidget,
    );
    expect(service.installs, 0);
  });
}
