import 'dart:io';
import 'package:expense_tracker/core/database/private_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('expense_tracker/private_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    test(
      '$platform stores the ledger in application data and reuses it',
      () async {
        final support = await Directory.systemTemp.createTemp(
          'desktop storage ',
        );
        addTearDown(() => support.delete(recursive: true));
        final path = await prepareLedgerDirectory(
          platform: platform,
          supportDirectory: () async => support,
        );
        final sentinel = File('$path/existing-data');
        await sentinel.writeAsString('preserve');
        expect(
          await prepareLedgerDirectory(
            platform: platform,
            supportDirectory: () async => support,
          ),
          path,
        );
        expect(await sentinel.readAsString(), 'preserve');
        expect(path, contains(support.path));
      },
    );
  }
  test('desktop rejects a relative support directory', () async {
    await expectLater(
      prepareLedgerDirectory(
        platform: TargetPlatform.windows,
        supportDirectory: () async => Directory('relative'),
      ),
      throwsStateError,
    );
  });

  test(
    'uses the native prepared absolute directory, including spaces',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        expect(call.method, 'prepareLedgerDirectory');
        return '/private/Application Support/ledger';
      });
      expect(
        await prepareLedgerDirectory(),
        '/private/Application Support/ledger',
      );
      expect(calls, 1);
    },
  );
  for (final path in <String?>[
    null,
    '',
    'relative/ledger',
    'file:///private/ledger',
    '/private/ledger\u0000',
  ]) {
    test(
      'refuses invalid native directory ${path == null ? 'null' : path.codeUnits}',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async => path);
        await expectLater(prepareLedgerDirectory(), throwsStateError);
      },
    );
  }
  test('missing native plugin does not fall back to public storage', () async {
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      prepareLedgerDirectory(),
      throwsA(isA<MissingPluginException>()),
    );
  });
  test(
    'native storage error is propagated without a fallback directory',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'storage_unavailable'),
      );
      await expectLater(
        prepareLedgerDirectory(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
