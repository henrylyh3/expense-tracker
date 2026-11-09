import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ledger_types.dart';

abstract class RelaySecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> clear();
}

class DeviceRelaySecrets implements RelaySecretStore {
  // A single-app desktop install does not need a shared Keychain group or
  // a machine-specific provisioning profile. Mobile defaults are unchanged.
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _prefix = 'expense_discord_';
  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');
  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: '$_prefix$key')
      : _storage.write(key: '$_prefix$key', value: value);
  @override
  Future<void> clear() async {
    final values = await _storage.readAll();
    for (final key in values.keys.where((key) => key.startsWith(_prefix))) {
      await _storage.delete(key: key);
    }
  }
}

class DiscordConnection {
  const DiscordConnection(this.webhook, this.trip);
  final Uri webhook;
  final String trip;
  static bool matches(String endpoint) => endpoint.startsWith('discord:');
  static Uri validateWebhook(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        uri.host != 'discord.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port != 443 ||
        !RegExp(
          r'^/api/webhooks/[0-9]{15,22}/[A-Za-z0-9_-]{20,200}$',
        ).hasMatch(uri.path)) {
      throw const LedgerException(
        'Use a Discord webhook URL from discord.com.',
      );
    }
    return uri;
  }

  static DiscordConnection decode(String source) {
    if (!matches(source) || source.length > 2048) throw const FormatException();
    final value =
        jsonDecode(utf8.decode(base64Url.decode(source.substring(8)))) as Map;
    final trip = value['trip'] as String;
    if (trip.isEmpty || trip.length > 80) throw const FormatException();
    return DiscordConnection(validateWebhook(value['webhook'] as String), trip);
  }

  String encode() =>
      'discord:${base64UrlEncode(utf8.encode(jsonEncode({'webhook': webhook.toString(), 'trip': trip})))}';
}

class DiscordUnavailable implements Exception {
  const DiscordUnavailable();
}

/// Only talks to Discord's HTTPS API and attachment CDN. Never follows redirects
/// with credentials and never includes tokens or server response bodies in errors.
class DiscordApi {
  static final _base = Uri.parse('https://discord.com/api/v10');
  DateTime? _retryAt;
  Future<Object?> request(
    String method,
    Uri uri, {
    String? token,
    Map<String, Object?>? json,
    Map<String, Object?>? packet,
  }) async {
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
      throw const LedgerException(
        'Discord is busy. Wait a moment before retrying.',
      );
    }
    if (packet != null && utf8.encode(jsonEncode(packet)).length > 2097152) {
      throw const LedgerException('The shared trip view is too large to sync.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      req.followRedirects = false;
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bot $token');
      }
      if (packet != null) {
        final boundary = 'expense${DateTime.now().microsecondsSinceEpoch}';
        req.headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary',
        );
        req.write(
          '--$boundary\r\nContent-Disposition: form-data; name="payload_json"\r\nContent-Type: application/json\r\n\r\n',
        );
        req.write(
          jsonEncode({
            'content': 'Expense Tracker encrypted sync',
            'allowed_mentions': {'parse': <String>[]},
            'attachments': [
              {'id': 0, 'filename': 'expense-relay.json'},
            ],
          }),
        );
        req.write(
          '\r\n--$boundary\r\nContent-Disposition: form-data; name="files[0]"; filename="expense-relay.json"\r\nContent-Type: application/json\r\n\r\n',
        );
        req.add(utf8.encode(jsonEncode(packet)));
        req.write('\r\n--$boundary--\r\n');
      } else if (json != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(json));
      }
      final res = await req.close().timeout(const Duration(seconds: 20));
      final bytes = <int>[];
      await for (final part in res.timeout(const Duration(seconds: 20))) {
        bytes.addAll(part);
        if (bytes.length > 2097152) {
          throw const LedgerException('Discord response is too large.');
        }
      }
      if (res.statusCode == 429) {
        double delay = 30;
        try {
          delay = (jsonDecode(utf8.decode(bytes))['retry_after'] as num)
              .toDouble();
        } catch (_) {}
        _retryAt = DateTime.now().add(
          Duration(seconds: delay.clamp(1, 3600).ceil()),
        );
        throw const LedgerException(
          'Discord is busy. Wait a moment before retrying.',
        );
      }
      if (res.statusCode == 404) throw const DiscordUnavailable();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw const LedgerException(
          'Discord connection failed. Check the bot token, channel access, Message Content Intent and Manage Webhooks permission.',
        );
      }
      return bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    } on LedgerException {
      rethrow;
    } on DiscordUnavailable {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const LedgerException(
        'Cannot reach Discord. Your queued expenses are kept. Check your internet connection and retry.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> verify(String channel, String token) async {
    final info =
        await request(
              'GET',
              _base.resolve('/api/v10/channels/$channel'),
              token: token,
            )
            as Map;
    if (info['type'] != 0) {
      throw const LedgerException('Choose a regular Discord text channel.');
    }
    await messages(channel, token, null);
    // Creating invitations verifies Manage Webhooks without making a test webhook.
    await request(
      'GET',
      _base.resolve('/api/v10/channels/$channel/webhooks'),
      token: token,
    );
  }

  Future<Uri> createWebhook(String channel, String token) async {
    final data =
        await request(
              'POST',
              _base.resolve('/api/v10/channels/$channel/webhooks'),
              token: token,
              json: {'name': 'Expense Tracker guest'},
            )
            as Map;
    return DiscordConnection.validateWebhook(
      'https://discord.com/api/webhooks/${data['id']}/${data['token']}',
    );
  }

  Future<void> deleteWebhook(Uri webhook) async {
    try {
      await request('DELETE', webhook);
    } on DiscordUnavailable {
      /* Already removed. */
    }
  }

  Future<Map<String, dynamic>> post(
    Uri webhook,
    Map<String, Object?> packet,
  ) async => Map<String, dynamic>.from(
    await request(
          'POST',
          webhook.replace(queryParameters: {'wait': 'true'}),
          packet: packet,
        )
        as Map,
  );
  Future<Map<String, dynamic>> get(Uri webhook, String message) async =>
      Map<String, dynamic>.from(
        await request('GET', Uri.parse('$webhook/messages/$message')) as Map,
      );
  Future<void> reply(
    Uri webhook,
    String message,
    Map<String, Object?> packet,
  ) async {
    await request(
      'PATCH',
      Uri.parse('$webhook/messages/$message'),
      packet: packet,
    );
  }

  Future<List<Map<String, dynamic>>> messages(
    String channel,
    String token,
    String? after,
  ) async {
    final uri = _base
        .resolve('/api/v10/channels/$channel/messages')
        .replace(queryParameters: {'limit': '100', 'after': ?after});
    return (await request('GET', uri, token: token) as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> packet(Map<String, dynamic> message) async {
    final files = (message['attachments'] as List? ?? [])
        .whereType<Map<String, dynamic>>();
    final file = files
        .where((f) => f['filename'] == 'expense-relay.json')
        .firstOrNull;
    if (file == null) return null;
    if (file['size'] is! int || (file['size'] as int) > 2097152) {
      throw const FormatException();
    }
    final uri = Uri.parse(file['url'] as String);
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !{'cdn.discordapp.com', 'media.discordapp.net'}.contains(uri.host)) {
      throw const FormatException();
    }
    return Map<String, dynamic>.from(await request('GET', uri) as Map);
  }
}
