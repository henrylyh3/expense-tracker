import 'dart:convert';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/sharing/discord_api.dart';

class MemorySecrets implements RelaySecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> clear() async => values.clear();
}

class FakeDiscord extends DiscordApi {
  final webhooks = <String>{};
  final inbox = <Map<String, dynamic>>[];
  int next = 100000000000000;
  bool failReply = false;
  bool failDelete = false;
  @override
  Future<void> verify(String channel, String token) async {}
  @override
  Future<Uri> createWebhook(String channel, String token) async {
    final uri = Uri.parse(
      'https://discord.com/api/webhooks/${++next}/abcdefghijklmnopqrstuvwxyz123456',
    );
    webhooks.add(uri.toString());
    return uri;
  }

  void check(Uri webhook) {
    if (!webhooks.contains(webhook.toString())) {
      throw const DiscordUnavailable();
    }
  }

  @override
  Future<void> deleteWebhook(Uri webhook) async {
    if (failDelete) throw const LedgerException('Offline');
    webhooks.remove(webhook.toString());
  }

  @override
  Future<Object?> request(
    String method,
    Uri uri, {
    String? token,
    Map<String, Object?>? json,
    Map<String, Object?>? packet,
  }) async {
    check(uri);
    return <String, Object?>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    Uri webhook,
    Map<String, Object?> packet,
  ) async {
    check(webhook);
    final message = <String, dynamic>{
      'id': '${++next}',
      'webhook_id': webhook.pathSegments[2],
      'payload': jsonDecode(jsonEncode(packet)),
    };
    inbox.add(message);
    return message;
  }

  @override
  Future<Map<String, dynamic>> get(Uri webhook, String message) async {
    check(webhook);
    return inbox.firstWhere((m) => m['id'] == message);
  }

  @override
  Future<void> reply(
    Uri webhook,
    String message,
    Map<String, Object?> packet,
  ) async {
    check(webhook);
    if (failReply) {
      failReply = false;
      throw const LedgerException('Offline');
    }
    (await get(webhook, message))['payload'] = jsonDecode(jsonEncode(packet));
  }

  @override
  Future<List<Map<String, dynamic>>> messages(
    String channel,
    String token,
    String? after,
  ) async {
    final matching = inbox
        .where(
          (m) =>
              after == null ||
              BigInt.parse(m['id'] as String) > BigInt.parse(after),
        )
        .toList();
    return after == null
        ? matching.reversed.take(100).toList()
        : matching.take(100).toList();
  }

  @override
  Future<Map<String, dynamic>?> packet(Map<String, dynamic> message) async =>
      message['payload'] == null
      ? null
      : Map<String, dynamic>.from(message['payload'] as Map);
}
