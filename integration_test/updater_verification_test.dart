import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('expense_tracker/updates');
  testWidgets('Android updater rejects untrusted files before installation', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final info = await channel.invokeMapMethod<String, dynamic>(
        'installedInfo',
      );
      expect(info!['versionCode'], greaterThan(0));
      final path = await channel.invokeMethod<String>('prepareUpdateDirectory');
      final file = File('$path/update.apk');
      await file.writeAsBytes([1, 2, 3]);
      await expectLater(
        channel.invokeMethod<void>('verifyApk', {
          'path': file.path,
          'versionCode': 999999,
          'size': 3,
          'sha256': '0' * 64,
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(await file.exists(), isFalse);
      await expectLater(
        channel.invokeMethod<void>('verifyApk', {
          'path': '$path/../outside.apk',
          'versionCode': 999999,
          'size': 3,
          'sha256': '0' * 64,
        }),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
