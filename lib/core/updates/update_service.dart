import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const updateRepository = 'henrylyh3/expense-tracker';
const updatePackage = 'com.example.expense_tracker';
const maxUpdateBytes = 256 * 1024 * 1024;

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService();
  ref.onDispose(service.cancel);
  return service;
});

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.versionCode,
    required this.size,
    required this.sha256,
    required this.url,
    required this.notes,
  });
  final String version;
  final int versionCode;
  final int size;
  final String sha256;
  final Uri url;
  final String notes;

  static UpdateRelease parse(
    Map<String, dynamic> release,
    Map<String, dynamic> manifest,
  ) {
    final version = manifest['version'];
    final code = manifest['version_code'];
    final size = manifest['size'];
    final hash = manifest['sha256'];
    if (manifest['schema'] != 1 ||
        version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        code is! int ||
        code <= 0 ||
        size is! int ||
        size <= 0 ||
        size > maxUpdateBytes ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        manifest['package'] != updatePackage ||
        manifest['abi'] != 'arm64-v8a' ||
        release['tag_name'] != 'v$version' ||
        release['draft'] != false ||
        release['prerelease'] != false) {
      throw const FormatException('Invalid update information.');
    }
    final name = 'expense-tracker-$version-arm64-release.apk';
    if (manifest['apk'] != name) {
      throw const FormatException('Invalid update file.');
    }
    final assets = release['assets'];
    if (assets is! List) throw const FormatException('Missing update file.');
    final matching = assets
        .whereType<Map<String, dynamic>>()
        .where((a) => a['name'] == name)
        .toList();
    if (matching.length != 1) {
      throw const FormatException('Missing update file.');
    }
    final asset = matching.single;
    final url = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
    final expected =
        'https://github.com/$updateRepository/releases/download/v$version/$name';
    if (url?.toString() != expected ||
        asset['size'] != size ||
        asset['digest'] != 'sha256:$hash') {
      throw const FormatException(
        'Update file verification information does not match.',
      );
    }
    final notes = release['body'];
    return UpdateRelease(
      version: version,
      versionCode: code,
      size: size,
      sha256: hash,
      url: url!,
      notes: notes is String
          ? notes.substring(0, notes.length > 8000 ? 8000 : notes.length)
          : '',
    );
  }

  Map<String, Object> nativeArguments(String path) => {
    'path': path,
    'versionCode': versionCode,
    'sha256': sha256,
    'size': size,
  };
}

class UpdateCancelled implements Exception {}

class UpdateService {
  UpdateService({HttpClient Function()? clientFactory, MethodChannel? channel})
    : _clientFactory = clientFactory ?? HttpClient.new,
      _channel = channel ?? const MethodChannel('expense_tracker/updates');
  final HttpClient Function() _clientFactory;
  final MethodChannel _channel;
  HttpClient? _active;
  bool _cancelled = false;
  bool _working = false;
  Future<UpdateRelease?>? _pendingCheck;
  int? deferredVersion;

  static Uri freshUrl(Uri uri) => uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      '_check': DateTime.now().microsecondsSinceEpoch.toString(),
    },
  );

  void cancel() {
    _cancelled = true;
    _active?.close(force: true);
  }

  static bool allowedUrl(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      const {
        'api.github.com',
        'github.com',
        'release-assets.githubusercontent.com',
        'objects.githubusercontent.com',
        'github-releases.githubusercontent.com',
      }.contains(uri.host);

  Future<HttpClientResponse> _get(HttpClient client, Uri uri) async {
    for (var redirects = 0; redirects < 6; redirects++) {
      if (!allowedUrl(uri)) {
        throw const FormatException('Unsupported update download address.');
      }
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ExpenseTracker-Updater',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        uri.host == 'api.github.com'
            ? 'application/vnd.github+json'
            : 'application/octet-stream',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const FormatException('Invalid update redirect.');
        }
        uri = uri.resolve(location);
        continue;
      }
      return response;
    }
    throw const FormatException('Too many update redirects.');
  }

  Future<Map<String, dynamic>?> _json(
    HttpClient client,
    Uri uri, {
    bool allowMissing = false,
  }) async {
    final response = await _get(client, freshUrl(uri));
    if (allowMissing && response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw const HttpException('Unable to check for updates.');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > 262144) {
        throw const FormatException('Update information is too large.');
      }
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid update response.');
    }
    return decoded;
  }

  Future<UpdateRelease?> check() async {
    return _pendingCheck ??= _checkWithRetry().whenComplete(() {
      _pendingCheck = null;
    });
  }

  Future<UpdateRelease?> _checkWithRetry() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _check();
      } catch (_) {
        if (attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  Future<UpdateRelease?> _check() async {
    if (_working) throw StateError('An update download is already running.');
    _working = true;
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    _active = client;
    try {
      final installed = await _channel.invokeMapMethod<String, dynamic>(
        'installedInfo',
      );
      if (installed == null || !(installed['arm64'] as bool? ?? false)) {
        return null;
      }
      final release = await _json(
        client,
        Uri.parse(
          'https://api.github.com/repos/$updateRepository/releases/latest',
        ),
        allowMissing: true,
      );
      if (release == null) return null;
      final tag = release['tag_name'];
      if (tag is! String || !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag)) {
        throw const FormatException('Invalid update version.');
      }
      final assets = release['assets'];
      if (assets is! List) {
        throw const FormatException('Missing update information.');
      }
      final manifests = assets
          .whereType<Map<String, dynamic>>()
          .where((a) => a['name'] == 'update.json')
          .toList();
      if (manifests.length != 1) {
        throw const FormatException('Missing update information.');
      }
      final expected =
          'https://github.com/$updateRepository/releases/download/$tag/update.json';
      if (manifests.single['browser_download_url'] != expected) {
        throw const FormatException('Invalid update information address.');
      }
      final manifest = await _json(client, Uri.parse(expected));
      final update = UpdateRelease.parse(release, manifest!);
      return update.versionCode > (installed['versionCode'] as int)
          ? update
          : null;
    } finally {
      client.close(force: true);
      _active = null;
      _working = false;
    }
  }

  Future<String> download(
    UpdateRelease update,
    void Function(int, int) progress,
  ) async {
    if (_working) throw StateError('An update operation is already running.');
    _working = true;
    _cancelled = false;
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    _active = client;
    File? file;
    IOSink? sink;
    var complete = false;
    try {
      final directory = await _channel.invokeMethod<String>(
        'prepareUpdateDirectory',
      );
      if (directory == null) {
        throw const FileSystemException('Cannot prepare update download.');
      }
      file = File('$directory/update.apk');
      sink = file.openWrite();
      final response = await _get(client, freshUrl(update.url));
      if (response.statusCode != 200 ||
          (response.contentLength >= 0 &&
              response.contentLength != update.size)) {
        throw const HttpException('Unable to download the complete update.');
      }
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (_cancelled) throw UpdateCancelled();
        received += chunk.length;
        if (received > update.size || received > maxUpdateBytes) {
          throw const FormatException('Update download size does not match.');
        }
        sink.add(chunk);
        await sink.flush();
        progress(received, update.size);
      }
      await sink.close();
      sink = null;
      if (_cancelled) throw UpdateCancelled();
      if (received != update.size) {
        throw const FormatException('Update download is incomplete.');
      }
      await _channel.invokeMethod<void>(
        'verifyApk',
        update.nativeArguments(file.path),
      );
      if (_cancelled) throw UpdateCancelled();
      complete = true;
      return file.path;
    } catch (_) {
      if (_cancelled) throw UpdateCancelled();
      rethrow;
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        // Cleanup still runs if storage fails while flushing a partial file.
      }
      client.close(force: true);
      _active = null;
      _working = false;
      if (!complete && file != null) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // The next download recreates the private cache file.
        }
      }
    }
  }

  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;
  Future<void> requestPermission() =>
      _channel.invokeMethod<void>('requestInstallPermission');
  Future<void> install(UpdateRelease release, String path) =>
      _channel.invokeMethod<void>('installApk', release.nativeArguments(path));
}
