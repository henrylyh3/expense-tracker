import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/core/updates/update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/updates');
  late Directory directory;
  late HttpServer server;
  late UpdateService service;
  late Map<String, dynamic> manifest;
  late Map<String, dynamic> release;
  late List<String> calls;
  var installedCode = 2010;
  var mode = 'ok';
  final bytes = List.generate(128, (i) => i);
  final hash = 'a' * 64;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('expense-update-test-');
    calls = [];
    installedCode = 2010;
    mode = 'ok';
    manifest = {
      'schema': 1,
      'version': '0.4.2',
      'version_code': 2011,
      'size': bytes.length,
      'sha256': hash,
      'package': updatePackage,
      'abi': 'arm64-v8a',
      'apk': 'expense-tracker-0.4.2-arm64-release.apk',
    };
    release = {
      'tag_name': 'v0.4.2',
      'draft': false,
      'prerelease': false,
      'body': 'New updates',
      'assets': [
        {
          'name': 'update.json',
          'browser_download_url':
              'https://github.com/$updateRepository/releases/download/v0.4.2/update.json',
        },
        {
          'name': manifest['apk'],
          'size': bytes.length,
          'digest': 'sha256:$hash',
          'browser_download_url':
              'https://github.com/$updateRepository/releases/download/v0.4.2/${manifest['apk']}',
        },
      ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'installedInfo':
              return {'versionCode': installedCode, 'arm64': true};
            case 'prepareUpdateDirectory':
              return directory.path;
            case 'verifyApk':
              expect(
                await File('${directory.path}/update.apk').readAsBytes(),
                bytes,
              );
              if (mode == 'bad-signature') {
                throw PlatformException(code: 'update_verification_failed');
              }
              return null;
            default:
              return true;
          }
        });
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (mode == 'offline') {
        request.response.statusCode = 503;
      } else if (mode == 'missing') {
        request.response.statusCode = 404;
      } else if (request.uri.path.endsWith('/latest')) {
        request.response.write(jsonEncode(release));
      } else if (request.uri.path.endsWith('update.json')) {
        request.response.write(jsonEncode(manifest));
      } else if (mode == 'redirect') {
        request.response.statusCode = 302;
        request.response.headers.set(
          'location',
          'http://untrusted.example/update.apk',
        );
      } else {
        request.response.add(
          mode == 'truncated' ? bytes.take(64).toList() : bytes,
        );
      }
      await request.response.close();
    });
    service = UpdateService(
      clientFactory: () => _LocalClient(server.port),
      channel: channel,
    );
  });
  tearDown(() async {
    service.cancel();
    await server.close(force: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  test(
    'checks installed build and only offers a newer verified release',
    () async {
      expect((await service.check())!.versionCode, 2011);
      installedCode = 2011;
      expect(await service.check(), isNull);
      installedCode = 2012;
      expect(await service.check(), isNull);
      mode = 'missing';
      expect(await service.check(), isNull);
      mode = 'offline';
      await expectLater(service.check(), throwsA(isA<HttpException>()));
    },
  );
  test('rejects a wrong package, release hash, asset URL and prerelease', () {
    for (final invalid in [
      {...manifest, 'package': 'other.app'},
      {...manifest, 'sha256': 'b' * 64},
      {...manifest, 'version_code': '2011'},
      {...manifest, 'abi': 'x86_64'},
    ]) {
      expect(
        () => UpdateRelease.parse(release, invalid),
        throwsFormatException,
      );
    }
    expect(
      () => UpdateRelease.parse({...release, 'prerelease': true}, manifest),
      throwsFormatException,
    );
    (release['assets'] as List)[1]['browser_download_url'] =
        'http://github.com/untrusted.apk';
    expect(() => UpdateRelease.parse(release, manifest), throwsFormatException);
  });
  test(
    'downloads a bounded file then delegates APK authenticity verification',
    () async {
      final update = (await service.check())!;
      final path = await service.download(
        update,
        (received, total) => expect(received <= total, isTrue),
      );
      expect(await File(path).readAsBytes(), bytes);
      expect(calls.where((c) => c == 'verifyApk'), hasLength(1));
    },
  );
  test(
    'failed size, redirect, signature and cancellation remove incomplete files',
    () async {
      final update = (await service.check())!;
      for (final failure in [
        'truncated',
        'redirect',
        'bad-signature',
        'cancel',
      ]) {
        mode = failure;
        await expectLater(
          service.download(update, (_, _) {
            if (failure == 'cancel') service.cancel();
          }),
          throwsA(anything),
        );
        expect(await File('${directory.path}/update.apk').exists(), isFalse);
      }
    },
  );
}

class _LocalClient extends Fake implements HttpClient {
  _LocalClient(this.port);
  final int port;
  final inner = HttpOverrides.runWithHttpOverrides(
    HttpClient.new,
    _RealHttpOverrides(),
  );
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> getUrl(Uri url) => inner.getUrl(
    Uri(scheme: 'http', host: '127.0.0.1', port: port, path: url.path),
  );
  @override
  void close({bool force = false}) => inner.close(force: force);
}

class _RealHttpOverrides extends HttpOverrides {}
