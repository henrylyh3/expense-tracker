import 'dart:async';

import 'package:expense_tracker/core/updates/desktop_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unconfigured background check is quiet; manual check explains setup',
    () async {
      final updater = DesktopUpdater(supported: true);
      await updater.check(background: true);
      await expectLater(updater.check(), throwsStateError);
    },
  );
  for (final feed in [
    'http://example.com/feed',
    'https://user:secret@example.com/feed',
    'relative.xml',
    'https://example.com/feed#fragment',
  ]) {
    test('rejects unsafe feed $feed before native initialization', () async {
      final updater = DesktopUpdater(
        supported: true,
        signingConfigured: true,
        feedUrl: feed,
        setFeed: (_) async => fail('Must not initialize an unsafe feed'),
      );
      await expectLater(updater.check(), throwsStateError);
    });
  }
  test('requires signing configuration even for HTTPS', () async {
    final updater = DesktopUpdater(
      supported: true,
      feedUrl: 'https://example.com/feed',
    );
    await expectLater(updater.check(), throwsStateError);
  });
  test(
    'initializes once, disables scheduling and coalesces concurrent checks',
    () async {
      final calls = <String>[];
      final gate = Completer<void>();
      final updater = DesktopUpdater(
        supported: true,
        signingConfigured: true,
        feedUrl: 'https://example.com/feed',
        setFeed: (url) async => calls.add(url),
        setInterval: (seconds) async => calls.add('interval:$seconds'),
        checkNative: (background) async {
          calls.add('check:$background');
          await gate.future;
        },
      );
      final first = updater.check(background: true);
      final second = updater.check(background: true);
      expect(identical(first, second), isTrue);
      gate.complete();
      await first;
      await updater.check();
      expect(calls, [
        'https://example.com/feed',
        'interval:0',
        'check:true',
        'check:false',
      ]);
    },
  );
  test('initialization failure can be retried', () async {
    var attempts = 0;
    final updater = DesktopUpdater(
      supported: true,
      signingConfigured: true,
      feedUrl: 'https://example.com/feed',
      setFeed: (_) async {
        if (++attempts == 1) throw StateError('offline');
      },
      setInterval: (_) async {},
      checkNative: (_) async {},
    );
    await expectLater(updater.check(), throwsStateError);
    await updater.check();
    expect(attempts, 2);
  });
}
