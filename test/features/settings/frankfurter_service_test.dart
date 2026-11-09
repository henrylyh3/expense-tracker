import 'dart:io';

import 'package:expense_tracker/features/currencies/data/frankfurter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses the requested pair and rounds the exact decimal token to supported precision',
    () {
      final quote = FrankfurterService.parse(
        '{"date":"2026-11-09","base":"THB","quote":"MYR","rate":0.1234567890125}',
        'THB',
      );
      expect(quote.rate, '0.123456789013');
      expect(quote.date.toString(), '2026-11-09');
      expect(
        FrankfurterService.parse(
          '{"date":"2026-11-09","base":"THB","quote":"MYR","rate":1.21e-1}',
          'THB',
        ).rate,
        '0.121',
      );
    },
  );
  test('rejects malformed, inverse, zero and duplicate rate responses', () {
    for (final body in [
      '{"date":"2026-11-09","base":"MYR","quote":"THB","rate":8}',
      '{"date":"2026-02-30","base":"THB","quote":"MYR","rate":0.12}',
      '{"date":"2026-11-09","base":"THB","quote":"MYR","rate":0}',
      '{"date":"2026-11-09","base":"THB","quote":"MYR","rate":0.12,"rate":0.13}',
      '{"date":"2026-11-09","base":"THB","quote":"MYR","rate":"0.12"}',
    ]) {
      expect(() => FrankfurterService.parse(body, 'THB'), throwsA(anything));
    }
  });
  test(
    'requests one pair over HTTPS and rejects error or oversized responses',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <Uri>[];
      var mode = 'ok';
      server.listen((request) async {
        if (mode == 'error') {
          request.response.statusCode = 422;
        } else if (mode == 'large') {
          request.response.write('x' * 17000);
        } else {
          request.response.write(
            '{"date":"2026-11-09","base":"THB","quote":"MYR","rate":0.121}',
          );
        }
        await request.response.close();
      });
      try {
        final service = FrankfurterService(
          clientFactory: () => _Client(server.port, requests),
        );
        expect((await service.fetch('thb')).rate, '0.121');
        expect(
          requests.single.toString(),
          'https://api.frankfurter.dev/v2/rate/thb/myr',
        );
        mode = 'error';
        await expectLater(service.fetch('THB'), throwsA(isA<HttpException>()));
        mode = 'large';
        await expectLater(service.fetch('THB'), throwsFormatException);
      } finally {
        await server.close(force: true);
      }
    },
  );
}

class _Client extends Fake implements HttpClient {
  _Client(this.port, this.requests);
  final int port;
  final List<Uri> requests;
  final inner = HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttp());
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requests.add(url);
    return inner.getUrl(
      Uri(scheme: 'http', host: '127.0.0.1', port: port, path: url.path),
    );
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

class _RealHttp extends HttpOverrides {}
