import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../dates/calendar_date.dart';
import '../models/ledger_types.dart';
import '../money/money.dart';
import '../money/exchange_rate.dart';
import '../validation/input_validation.dart';
import '../../features/currencies/data/currency_repository.dart';
import '../../features/reports/data/report_repository.dart';
import '../../features/reports/domain/report_period.dart';
import '../../features/transactions/data/transaction_repository.dart';
import '../../features/transactions/domain/transaction_input.dart';
import 'sharing_cipher.dart';
import 'discord_api.dart';

part 'discord_sharing.dart';

class DiscordSyncProgress {
  const DiscordSyncProgress(this.stage, {this.completed = 0, this.total});
  final String stage;
  final int completed;
  final int? total;
}

class SharingService {
  SharingService(
    this.db, {
    DiscordApi? discordApi,
    RelaySecretStore? relaySecrets,
  }) : discordApi = discordApi ?? DiscordApi(),
       relaySecrets = relaySecrets ?? DeviceRelaySecrets();
  final DiscordApi discordApi;
  final RelaySecretStore relaySecrets;
  bool _discordPolling = false;
  final _discordProgress = StreamController<DiscordSyncProgress>.broadcast();
  Stream<DiscordSyncProgress> get discordProgress => _discordProgress.stream;
  void _reportDiscord(DiscordSyncProgress value) {
    if (!_discordProgress.isClosed) _discordProgress.add(value);
  }

  Future<void> dispose() async {
    await stopHost();
    await _discordProgress.close();
  }

  final AppDatabase db;
  final cipher = SharingCipher();
  HttpServer? _server;
  bool _syncing = false;
  int get port => _server?.port ?? 0;
  bool get hosting => _server != null;

  Stream<List<Map<String, Object?>>> watchSessions() => db
      .customSelect(
        'SELECT id, role, name, endpoint, cache FROM shared_sessions ORDER BY name, id',
        readsFrom: {db.sharedSessions},
      )
      .watch()
      .map((rows) => [for (final row in rows) row.data]);

  Future<void> startHost({
    InternetAddress? address,
    int bindPort = 45873,
  }) async {
    if (_server != null) return;
    _server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      bindPort,
    );
    _server!.listen((request) {
      unawaited(_serve(request));
    });
  }

  Future<void> stopHost() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<List<String>> hostAddresses() async => [
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ))
      for (final address in interface.addresses)
        if (!address.isLoopback && !address.address.startsWith('169.254.'))
          address.address,
  ];

  Uri validateEndpoint(String source) {
    final uri = Uri.parse(source);
    final ip = InternetAddress.tryParse(uri.host);
    if (uri.scheme != 'http' ||
        ip == null ||
        ip.type != InternetAddressType.IPv4 ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const LedgerException(
        'Enter the host Wi-Fi IPv4 address, for example http://192.168.1.20:45873.',
      );
    }
    final b = ip.rawAddress;
    final local =
        b[0] == 10 ||
        b[0] == 127 ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31);
    if (!local || uri.port < 1 || uri.port > 65535) {
      throw const LedgerException('Use a local Wi-Fi or hotspot address.');
    }
    return uri.replace(path: '', fragment: '');
  }

  Future<String> invite(String trip, String guest, String endpoint) async {
    if (!hosting) throw const LedgerException('Start hosting first.');
    final uri = validateEndpoint(endpoint);
    final id = const Uuid().v4();
    final key = await cipher.newKey();
    final name = requiredText(guest, label: 'Guest name', maxLength: 80);
    await db.writeTransaction(() async {
      await db.customInsert(
        "INSERT INTO shared_sessions (id, role, trip_id, name, secret, endpoint) VALUES (?, 'host', ?, ?, ?, ?)",
        variables: [
          Variable.withString(id),
          Variable.withString(trip),
          Variable.withString(name),
          Variable.withString(key),
          Variable.withString(uri.toString()),
        ],
        updates: {db.sharedSessions},
      );
    });
    return 'expense-trip:${base64UrlEncode(utf8.encode(jsonEncode({'version': 1, 'id': id, 'key': key, 'endpoint': uri.toString(), 'name': name})))}';
  }

  Future<void> join(String invitation) async {
    if (invitation.length > 4096 || !invitation.startsWith('expense-trip:')) {
      throw const LedgerException('Paste a complete trip invitation.');
    }
    try {
      final value =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(
                    invitation.substring('expense-trip:'.length),
                  ),
                ),
              )
              as Map<String, dynamic>;
      final id = value['id'] as String;
      final key = value['key'] as String;
      if (!{1, 2}.contains(value['version']) ||
          !Uuid.isValidUUID(fromString: id) ||
          base64Url.decode(key).length != 32) {
        throw const FormatException();
      }
      final endpoint = value['version'] == 2
          ? DiscordConnection.decode(value['endpoint'] as String).encode()
          : validateEndpoint(value['endpoint'] as String).toString();
      final name = requiredText(
        value['name'] as String,
        label: 'Invitation name',
        maxLength: 80,
      );
      await db.writeTransaction(() async {
        final previous = await db
            .customSelect(
              'SELECT role FROM shared_sessions WHERE id = ?',
              variables: [Variable.withString(id)],
            )
            .getSingleOrNull();
        if (previous != null) {
          throw const LedgerException(
            'This invitation is already on this device.',
          );
        }
        await db.customInsert(
          "INSERT INTO shared_sessions (id, role, name, secret, endpoint) VALUES (?, 'guest', ?, ?, ?)",
          variables: [
            Variable.withString(id),
            Variable.withString(name),
            Variable.withString(key),
            Variable.withString(endpoint),
          ],
          updates: {db.sharedSessions},
        );
      });
    } on LedgerException {
      rethrow;
    } catch (_) {
      throw const LedgerException('This invitation is invalid.');
    }
  }

  Future<void> revoke(String id) async {
    final session = await _session(id);
    // Persist removal before the network call. Revoked guests cannot insert.
    if (session['role'] == 'host' &&
        DiscordConnection.matches(session['endpoint'] as String)) {
      final pending =
          ((jsonDecode(await relaySecrets.read('revocations') ?? '[]')) as List)
              .cast<String>()
              .toSet()
            ..add(session['endpoint'] as String);
      await relaySecrets.write('revocations', jsonEncode(pending.toList()));
    }
    await db.writeTransaction(() async {
      await db.customUpdate(
        'DELETE FROM shared_sessions WHERE id = ?',
        variables: [Variable.withString(id)],
        updates: {db.sharedSessions, db.sharedPending, db.sharedReceipts},
      );
    });
    if (DiscordConnection.matches(session['endpoint'] as String)) {
      await retryDiscordRevocations();
    }
  }

  Future<void> discardPending(String session, String id) =>
      db.writeTransaction(() async {
        await db.customUpdate(
          'DELETE FROM shared_pending WHERE session_id = ? AND id = ?',
          variables: [Variable.withString(session), Variable.withString(id)],
          updates: {db.sharedPending},
        );
      });

  Future<void> updateEndpoint(String id, String endpoint) =>
      db.writeTransaction(() async {
        await db.customUpdate(
          'UPDATE shared_sessions SET endpoint = ? WHERE id = ?',
          variables: [
            Variable.withString(validateEndpoint(endpoint).toString()),
            Variable.withString(id),
          ],
          updates: {db.sharedSessions},
        );
      });

  Future<Map<String, Object?>> _session(String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM shared_sessions WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const LedgerException('This invitation has been removed.');
    }
    return row.data;
  }

  Future<Map<String, Object?>> snapshot(String trip) =>
      db.exclusiveLedgerOperation(() => _snapshot(trip));

  Future<Map<String, Object?>> _snapshot(String trip) async {
    final name =
        (await db
                .customSelect(
                  'SELECT name FROM trips WHERE id = ?',
                  variables: [Variable.withString(trip)],
                )
                .getSingle())
            .read<String>('name');
    final report = await ReportRepository(
      db,
    ).watchPeriod(ReportPeriod.trip(), expensesOnly: true, tripId: trip).first;
    final categories = await db
        .customSelect(
          "SELECT id, name FROM categories WHERE type = 'expense' AND is_archived = 0 ORDER BY sort_order LIMIT 5000",
        )
        .get();
    final overrides = await db
        .customSelect(
          'SELECT currency_code, rate_to_myr, name, rate_id FROM trip_rates WHERE trip_id = ?',
          variables: [Variable.withString(trip)],
        )
        .get();
    final rates = {
      for (final row in overrides) row.read<String>('currency_code'): row,
    };
    final currencies = await CurrencyRepository(db).watchAll().first;
    final preferences = await db
        .customSelect(
          'SELECT key, value FROM app_settings WHERE key IN (?, ?)',
          variables: [
            Variable.withString('default_rate'),
            Variable.withString('default_currency'),
          ],
        )
        .get();
    final selected = {
      for (final row in preferences)
        row.read<String>('key'): row.read<String>('value'),
    };
    final preferred =
        selected['default_rate'] ?? selected['default_currency'] ?? 'MYR';
    final defaultCurrency =
        currencies.any((c) => c.isActive && c.key == preferred)
        ? preferred
        : 'MYR';
    final rows = await TransactionRepository(
      db,
    ).watchHistory(tripId: trip, limit: 100).first;
    return {
      'name': name,
      'total_myr_minor': report.expenseMinor.toString(),
      'count': report.expenseCount,
      'default_currency': defaultCurrency,
      'categories': [
        for (final row in categories)
          {'id': row.read<String>('id'), 'name': row.read<String>('name')},
      ],
      'currencies': [
        for (final c in currencies.where(
          (c) =>
              c.isActive &&
              (c.recordId == null ||
                  c.key == defaultCurrency ||
                  rates[c.code]?.readNullable<String>('rate_id') == c.recordId),
        ))
          {
            'id': c.key,
            'code': c.code,
            'name': c.name,
            'precision': c.decimalPlaces,
            'rate': c.recordId == null
                ? rates[c.code]?.read<String>('rate_to_myr') ?? c.rateToMyr
                : c.rateToMyr,
          },
      ],
      'recent': [
        for (final row
            in rows
                .where((row) => row.type == TransactionType.expense)
                .take(100))
          {
            'category': row.categoryName,
            'amount': row.conversion.original.format(),
            'date': row.date.toString(),
            'note': row.note,
          },
      ],
      'synced_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> queue(String id, Map<String, Object?> expense) async {
    final session = await _session(id);
    if (session['role'] != 'guest') {
      throw const LedgerException('Only a guest queues expenses.');
    }
    final cache = session['cache'];
    if (cache is! String) {
      throw const LedgerException('Sync once before adding expenses.');
    }
    final data = jsonDecode(cache) as Map<String, dynamic>;
    final currency = (data['currencies'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => c['id'] == expense['currency_id']);
    Money.parseExpense(
      expense['amount'] as String,
      currencyCode: currency['code'] as String,
      decimalPlaces: currency['precision'] as int,
    );
    final payload = {
      'category': expense['category'],
      'currency': currency['code'],
      'amount': expense['amount'],
      'rate': currency['rate'],
      'date': expense['date'],
      'note': TransactionInput.normalizeNote(expense['note'] as String?),
    };
    _input(payload);
    await db.writeTransaction(() async {
      await db.customInsert(
        'INSERT INTO shared_pending VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(const Uuid().v4()),
          Variable.withString(id),
          Variable.withString(jsonEncode(payload)),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        ],
        updates: {db.sharedPending},
      );
    });
  }

  TransactionInput _input(Map<String, dynamic> data) => TransactionInput(
    type: TransactionType.expense,
    categoryId: data['category'] as String,
    currencyCode: data['currency'] as String,
    amountText: data['amount'] as String,
    date: CalendarDate.parse(data['date'] as String),
    note: data['note'] as String?,
    rateOverride: data['rate'] as String,
  );

  Future<String> _bounded(Stream<List<int>> stream, int limit) async {
    final chunks = <int>[];
    await for (final chunk in stream.timeout(const Duration(seconds: 20))) {
      if (chunks.length + chunk.length > limit) {
        throw const FormatException('Message too large');
      }
      chunks.addAll(chunk);
    }
    return utf8.decode(chunks);
  }

  Future<void> _serve(HttpRequest request) async {
    try {
      if (request.method != 'POST' || request.uri.path != '/sync') {
        request.response.statusCode = 404;
        return;
      }
      final packet =
          jsonDecode(await _bounded(request, 131072)) as Map<String, dynamic>;
      final id = packet['id'] as String;
      final session = await _session(id);
      if (session['role'] != 'host') throw const FormatException();
      final data = await cipher.open(
        packet,
        session['secret'] as String,
        'request:$id',
      );
      final requestId = data['request'] as String;
      if (!Uuid.isValidUUID(fromString: requestId)) {
        throw const FormatException();
      }
      final trip = session['trip_id'] as String;
      String? saved;
      if (data['action'] == 'add') {
        final submission = data['submission'] as String;
        if (!Uuid.isValidUUID(fromString: submission)) {
          throw const FormatException();
        }
        saved = await TransactionRepository(db).save(
          _input(data['expense'] as Map<String, dynamic>),
          sharedTripId: trip,
          sharedSessionId: id,
          sharedRequestId: submission,
        );
      } else if (data['action'] != 'read') {
        throw const FormatException();
      }
      final response = await cipher.seal(
        {
          'request': requestId,
          'saved': saved,
          'snapshot': await snapshot(trip),
        },
        session['secret'] as String,
        'response:$id:$requestId',
      );
      final encoded = jsonEncode(response);
      if (utf8.encode(encoded).length > 2097152) {
        throw const FormatException('Trip snapshot too large');
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(encoded);
    } catch (_) {
      request.response.statusCode = 403;
      request.response.write('Unable to process this shared trip request.');
    } finally {
      try {
        await request.response.close();
      } on IOException {
        // A disconnected guest retries with its original submission ID.
      }
    }
  }

  Future<Map<String, dynamic>> _send(
    Map<String, Object?> session,
    Map<String, Object?> data,
  ) async {
    if (DiscordConnection.matches(session['endpoint'] as String)) {
      return _sendDiscord(session, data);
    }
    final id = session['id'] as String;
    final requestId = const Uuid().v4();
    final uri = validateEndpoint(
      session['endpoint'] as String,
    ).replace(path: '/sync');
    final packet = await cipher.seal(
      {...data, 'request': requestId},
      session['secret'] as String,
      'request:$id',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'id': id, ...packet}));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await _bounded(response, 2097152);
      if (response.statusCode != 200) {
        throw const LedgerException(
          'The host refused this invitation or expense. Ask the host to check it.',
        );
      }
      final decoded = await cipher.open(
        jsonDecode(body) as Map<String, dynamic>,
        session['secret'] as String,
        'response:$id:$requestId',
      );
      if (decoded['request'] != requestId) throw const FormatException();
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sync(String id) async {
    if (_syncing) throw const LedgerException('A sync is already running.');
    _syncing = true;
    try {
      final session = await _session(id);
      if (session['role'] != 'guest') {
        throw const LedgerException('This is a host invitation.');
      }
      final pending = await db
          .customSelect(
            'SELECT id, payload FROM shared_pending WHERE session_id = ? ORDER BY created_at, id',
            variables: [Variable.withString(id)],
          )
          .get();
      for (final row in pending) {
        final response = await _send(session, {
          'action': 'add',
          'submission': row.read<String>('id'),
          'expense': jsonDecode(row.read<String>('payload')),
        });
        if (response['saved'] is! String) {
          throw const FormatException('Missing acknowledgement');
        }
        await db.writeTransaction(() async {
          await db.customUpdate(
            'DELETE FROM shared_pending WHERE id = ?',
            variables: [Variable.withString(row.read<String>('id'))],
            updates: {db.sharedPending},
          );
          await _cache(id, response['snapshot']);
        });
        if (DiscordConnection.matches(session['endpoint'] as String)) {
          await relaySecrets.write(
            'request:$id:${row.read<String>('id')}',
            null,
          );
        }
      }
      if (pending.isNotEmpty &&
          DiscordConnection.matches(session['endpoint'] as String)) {
        return;
      }
      final response = await _send(session, {'action': 'read'});
      await db.writeTransaction(() => _cache(id, response['snapshot']));
    } finally {
      _syncing = false;
    }
  }

  Future<void> _cache(String id, Object? snapshot) async {
    if (snapshot is! Map ||
        snapshot['total_myr_minor'] is! String ||
        snapshot['categories'] is! List ||
        snapshot['currencies'] is! List) {
      throw const FormatException('Invalid host snapshot');
    }
    String text(Object? value, int limit) {
      if (value is! String ||
          value.isEmpty ||
          value.runes.length > limit ||
          value.contains('\u0000')) {
        throw const FormatException('Invalid snapshot text');
      }
      return value;
    }

    text(snapshot['name'], 80);
    final total = text(snapshot['total_myr_minor'], 20);
    if (!RegExp(r'^[0-9]+$').hasMatch(total) ||
        snapshot['count'] is! int ||
        (snapshot['count'] as int) < 0) {
      throw const FormatException('Invalid host totals');
    }
    Money.checkedMinorUnits(BigInt.parse(total));
    if (DateTime.tryParse(text(snapshot['synced_at'], 40)) == null) {
      throw const FormatException('Invalid sync date');
    }
    for (final table in ['categories', 'currencies', 'recent']) {
      final rows = snapshot[table];
      if (rows is! List || rows.length > (table == 'recent' ? 100 : 5000)) {
        throw const FormatException('Invalid snapshot rows');
      }
      final ids = <String>{};
      for (final row in rows) {
        if (row is! Map) throw const FormatException('Invalid snapshot row');
        if (table == 'recent') {
          text(row['category'], 80);
          text(row['amount'], 80);
          CalendarDate.parse(text(row['date'], 10));
          TransactionInput.normalizeNote(row['note'] as String?);
        } else {
          if (!ids.add(text(row['id'], 80))) {
            throw const FormatException('Duplicate snapshot ID');
          }
          text(row['name'], 80);
          if (table == 'currencies') {
            final precision = row['precision'];
            if (precision is! int || precision < 0 || precision > 6) {
              throw const FormatException('Invalid precision');
            }
            Money.fromMinor(
              minorUnits: 0,
              currencyCode: text(row['code'], 3),
              decimalPlaces: precision,
            );
            normalizeExchangeRate(text(row['rate'], 25));
          }
        }
      }
    }
    await db.customUpdate(
      'UPDATE shared_sessions SET cache = ? WHERE id = ? AND role = \'guest\'',
      variables: [
        Variable.withString(jsonEncode(snapshot)),
        Variable.withString(id),
      ],
      updates: {db.sharedSessions},
    );
  }
}
