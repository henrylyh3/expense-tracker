import 'dart:convert';
import 'dart:io';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:expense_tracker/core/sharing/discord_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Discord HTTP adapter writes encrypted JSON attachment and disables mentions',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final observed = server.first.then((request) async {
        expect(request.headers.value('authorization'), 'Bot secret');
        expect(request.headers.contentType!.mimeType, 'multipart/form-data');
        final body = await utf8.decoder.bind(request).join();
        expect(
          body,
          contains('name="files[0]"; filename="expense-relay.json"'),
        );
        expect(body, contains('"allowed_mentions":{"parse":[]}'));
        expect(body, contains('"data":"ciphertext"'));
        expect(body, isNot(contains('Lunch')));
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"id":"123456789012345"}');
        await request.response.close();
      });
      final response = await DiscordApi().request(
        'POST',
        Uri.parse('http://127.0.0.1:${server.port}/test'),
        token: 'secret',
        packet: {'data': 'ciphertext', 'nonce': 'nonce', 'mac': 'mac'},
      );
      await observed;
      expect((response as Map)['id'], '123456789012345');
    },
  );
  test(
    'Discord HTTP adapter respects retry delay and does not expose response secrets',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      server.listen((request) async {
        calls++;
        await request.drain<void>();
        request.response.statusCode = 429;
        request.response.write('{"retry_after":60,"secret":"do-not-display"}');
        await request.response.close();
      });
      final api = DiscordApi();
      final uri = Uri.parse('http://127.0.0.1:${server.port}/test');
      final matcher = throwsA(
        isA<LedgerException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Discord is busy'), isNot(contains('do-not-display'))),
        ),
      );
      await expectLater(api.request('GET', uri), matcher);
      await expectLater(api.request('GET', uri), matcher);
      expect(calls, 1);
    },
  );
}
