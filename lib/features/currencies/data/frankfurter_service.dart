import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates/calendar_date.dart';
import '../../../core/money/exchange_rate.dart';

final frankfurterServiceProvider = Provider<FrankfurterService>(
  (ref) => FrankfurterService(),
);

class FrankfurterQuote {
  const FrankfurterQuote({required this.rate, required this.date});
  final String rate;
  final CalendarDate date;
}

class FrankfurterService {
  FrankfurterService({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;
  final HttpClient Function() _clientFactory;

  static FrankfurterQuote parse(String body, String code) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> ||
        data['base'] != code ||
        data['quote'] != 'MYR' ||
        data['date'] is! String ||
        data['rate'] is! num ||
        !(data['rate'] as num).isFinite ||
        (data['rate'] as num) <= 0) {
      throw const FormatException('Invalid reference rate.');
    }
    // Preserve the decimal token before JSON decoding can round it to double.
    final tokens = RegExp(
      r'"rate"\s*:\s*([0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*(?=[,}])',
    ).allMatches(body).toList();
    if (tokens.length != 1 || tokens.single.group(1)!.length > 80) {
      throw const FormatException('Invalid reference rate.');
    }
    final value = Decimal.parse(tokens.single.group(1)!).round(scale: 12);
    return FrankfurterQuote(
      rate: normalizeExchangeRate(value.toString()),
      date: CalendarDate.parse(data['date'] as String),
    );
  }

  Future<FrankfurterQuote> fetch(String sourceCode) async {
    final code = sourceCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) || code == 'MYR') {
      throw const FormatException('Choose a foreign currency.');
    }
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.https(
        'api.frankfurter.dev',
        '/v2/rate/${code.toLowerCase()}/myr',
      );
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ExpenseTracker-RatePrefill',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        throw const HttpException('Reference rate unavailable.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 16384) {
          throw const FormatException('Reference rate response is too large.');
        }
      }
      return parse(utf8.decode(bytes), code);
    } finally {
      client.close(force: true);
    }
  }
}
