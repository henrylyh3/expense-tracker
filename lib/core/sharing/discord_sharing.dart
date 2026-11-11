part of 'sharing_service.dart';

extension DiscordSharing on SharingService {
  Future<Map<String, dynamic>?> discordSettings() async {
    final raw = await relaySecrets.read('config');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> configureDiscord(String channel, String token) async {
    channel = channel.trim();
    token = token.trim();
    if (!RegExp(r'^[0-9]{15,22}$').hasMatch(channel) ||
        token.isEmpty ||
        token.contains(RegExp(r'\s'))) {
      throw const LedgerException(
        'Enter the Discord channel ID and bot token.',
      );
    }
    final old = await discordSettings();
    if (old != null && old['channel'] != channel) {
      final sessions = await db
          .customSelect(
            "SELECT id FROM shared_sessions WHERE role = 'host' AND endpoint LIKE 'discord:%'",
          )
          .get();
      if (sessions.isNotEmpty) {
        throw const LedgerException(
          'Revoke existing internet invitations before changing the Discord channel.',
        );
      }
    }
    await discordApi.verify(channel, token);
    if (old == null || old['channel'] != channel) {
      final messages = await discordApi.messages(channel, token, null);
      final latest = messages
          .map((m) => BigInt.parse(m['id'] as String))
          .fold<BigInt>(BigInt.zero, (a, b) => a > b ? a : b);
      await relaySecrets.write('cursor:$channel', latest.toString());
    }
    await relaySecrets.write(
      'config',
      jsonEncode({'channel': channel, 'token': token}),
    );
  }

  Future<void> clearDiscord() async {
    final sessions = await db
        .customSelect(
          "SELECT id FROM shared_sessions WHERE role = 'host' AND endpoint LIKE 'discord:%'",
        )
        .get();
    if (sessions.isNotEmpty) {
      throw const LedgerException(
        'Revoke internet invitations before removing this connection.',
      );
    }
    await retryDiscordRevocations();
    if (await relaySecrets.read('revocations') != null) {
      throw const LedgerException(
        'Connect to the internet to finish removing revoked webhooks first.',
      );
    }
    await relaySecrets.write('config', null);
  }

  Future<String> inviteDiscord(
    String trip,
    String guest, {
    Duration? validFor,
  }) async {
    if (validFor != null &&
        (validFor < const Duration(minutes: 1) ||
            validFor > const Duration(days: 30))) {
      throw const LedgerException(
        'Choose invitation access between one minute and 30 days.',
      );
    }
    final config = await discordSettings();
    if (config == null) {
      throw const LedgerException('Set up internet sharing first.');
    }
    final name = requiredText(guest, label: 'Guest name', maxLength: 80);
    final exists = await db
        .customSelect(
          'SELECT id FROM trips WHERE id = ?',
          variables: [Variable.withString(trip)],
        )
        .getSingleOrNull();
    if (exists == null) throw const LedgerException('Choose an existing trip.');
    final webhook = await discordApi.createWebhook(
      config['channel'] as String,
      config['token'] as String,
    );
    final id = const Uuid().v4();
    final key = await cipher.newKey();
    final expiry = validFor == null ? null : _clock().toUtc().add(validFor);
    final endpoint = DiscordConnection(
      webhook,
      trip,
      expiresAt: expiry,
    ).encode();
    try {
      await db.writeTransaction(() async {
        await db.customInsert(
          "INSERT INTO shared_sessions (id, role, trip_id, name, secret, endpoint) VALUES (?, 'host', ?, ?, ?, ?)",
          variables: [
            Variable.withString(id),
            Variable.withString(trip),
            Variable.withString(name),
            Variable.withString(key),
            Variable.withString(endpoint),
          ],
          updates: {db.sharedSessions},
        );
      });
    } catch (_) {
      await _scheduleWebhookRemoval(endpoint);
      rethrow;
    }
    return _discordInvitationCode(id, key, endpoint, name);
  }

  Future<String> inviteDiscordWeb(
    String trip,
    String guest,
    Uri page, {
    Duration validFor = const Duration(days: 7),
  }) async {
    _validateGuestPage(page);
    final code = await inviteDiscord(trip, guest, validFor: validFor);
    final invitation =
        jsonDecode(utf8.decode(base64Url.decode(code.substring(13))))
            as Map<String, dynamic>;
    final id = invitation['id'] as String;
    final connection = DiscordConnection.decode(
      invitation['endpoint'] as String,
    );
    try {
      final view = await snapshot(trip);
      // Discord keeps the encrypted initial view so the host can close immediately.
      final encrypted = await cipher.seal(
        {'snapshot': view},
        invitation['key'] as String,
        'discord-invite:$id:$trip',
      );
      final message = await discordApi.post(connection.webhook, {
        'direction': 'invite',
        'id': id,
        ...encrypted,
      });
      final messageId = message['id'];
      if (messageId is! String ||
          !RegExp(r'^[0-9]{15,22}$').hasMatch(messageId)) {
        throw const LedgerException(
          'Discord did not confirm storing this invitation. Try again.',
        );
      }
      await _saveWebInvitation(id, page, messageId);
      final webCode = _discordInvitationCode(
        id,
        invitation['key'] as String,
        invitation['endpoint'] as String,
        invitation['name'] as String,
        bootstrap: messageId,
      );
      return page.replace(fragment: 'invite=$webCode').toString();
    } catch (_) {
      await revoke(id);
      rethrow;
    }
  }

  Future<String> copyDiscordInvitation(String id, Uri legacyPage) async {
    final session = await _session(id);
    final endpoint = session['endpoint'] as String;
    if (session['role'] != 'host' || !DiscordConnection.matches(endpoint)) {
      throw const LedgerException('This is not an internet guest invitation.');
    }
    final connection = DiscordConnection.decode(endpoint);
    if (connection.expired(_clock().toUtc())) {
      throw const LedgerException('This invitation has expired.');
    }
    final key = session['secret'] as String;
    final name = session['name'] as String;
    if (connection.expiresAt == null) {
      return _discordInvitationCode(id, key, endpoint, name);
    }
    final saved = session['cache'] as String?;
    final metadata = saved == null
        ? null
        : jsonDecode(saved) as Map<String, dynamic>;
    final page = metadata == null
        ? legacyPage
        : Uri.parse(metadata['page'] as String);
    _validateGuestPage(page);
    final bootstrap = metadata == null
        ? await _recoverWebBootstrap(id, connection)
        : metadata['bootstrap'] as String;
    if (metadata == null) {
      if (connection.expired(_clock().toUtc())) {
        throw const LedgerException('This invitation has expired.');
      }
      await _saveWebInvitation(id, page, bootstrap);
    }
    final code = _discordInvitationCode(
      id,
      key,
      endpoint,
      name,
      bootstrap: bootstrap,
    );
    return page.replace(fragment: 'invite=$code').toString();
  }

  Future<void> _saveWebInvitation(String id, Uri page, String bootstrap) async {
    // Host cache holds only the page and message reference. Session credentials
    // remain in their existing fields and are never duplicated in the cache.
    final updated = await db.writeTransaction(
      () => db.customUpdate(
        "UPDATE shared_sessions SET cache = ? WHERE id = ? AND role = 'host'",
        variables: [
          Variable.withString(
            jsonEncode({'page': page.toString(), 'bootstrap': bootstrap}),
          ),
          Variable.withString(id),
        ],
        updates: {db.sharedSessions},
      ),
    );
    if (updated != 1) {
      throw const LedgerException('This invitation has been removed.');
    }
  }

  Future<String> _recoverWebBootstrap(
    String id,
    DiscordConnection connection,
  ) async {
    final config = await discordSettings();
    if (config == null) {
      throw const LedgerException('Set up internet sharing first.');
    }
    final webhookId = connection.webhook.pathSegments[2];
    // The original snapshot was posted after this invitation's webhook existed.
    var cursor = ((BigInt.parse(webhookId) >> 22) << 22) - BigInt.one;
    while (true) {
      final messages = await discordApi.messages(
        config['channel'] as String,
        config['token'] as String,
        cursor.toString(),
      );
      final previous = cursor;
      for (final message in messages) {
        final messageId = message['id'] as String;
        final number = BigInt.parse(messageId);
        if (number > cursor) cursor = number;
        if (message['webhook_id'] != webhookId) continue;
        final packet = await discordApi.packet(message);
        if (packet?['direction'] == 'invite' && packet?['id'] == id) {
          return messageId;
        }
      }
      if (messages.length < 100 || cursor == previous) break;
    }
    throw const LedgerException(
      'The original invitation message could not be found in Discord.',
    );
  }

  Future<void> _scheduleWebhookRemoval(String endpoint) async {
    final pending =
        ((jsonDecode(await relaySecrets.read('revocations') ?? '[]')) as List)
            .cast<String>()
            .toSet()
          ..add(endpoint);
    await relaySecrets.write('revocations', jsonEncode(pending.toList()));
    await retryDiscordRevocations();
  }

  Future<void> retryDiscordRevocations() async {
    final pending =
        ((jsonDecode(await relaySecrets.read('revocations') ?? '[]')) as List)
            .cast<String>();
    final remaining = <String>[];
    for (final endpoint in pending) {
      try {
        await discordApi.deleteWebhook(
          DiscordConnection.decode(endpoint).webhook,
        );
      } catch (_) {
        remaining.add(endpoint);
      }
    }
    await relaySecrets.write(
      'revocations',
      remaining.isEmpty ? null : jsonEncode(remaining),
    );
  }

  Future<void> pollDiscord() async {
    if (_discordPolling) return;
    _discordPolling = true;
    try {
      final config = await discordSettings();
      if (config == null) return;
      _reportDiscord(const DiscordSyncProgress('Connecting to Discord'));
      await retryDiscordRevocations();
      final candidates = await db
          .customSelect(
            "SELECT * FROM shared_sessions WHERE role = 'host' AND endpoint LIKE 'discord:%'",
          )
          .get();
      if (candidates.isEmpty) return;
      final channel = config['channel'] as String;
      var cursor = await relaySecrets.read('cursor:$channel') ?? '0';
      // Bound work per foreground tick; subsequent ticks continue from the cursor.
      for (var page = 0; page < 3; page++) {
        _reportDiscord(const DiscordSyncProgress('Fetching Discord requests'));
        final messages = await discordApi.messages(
          channel,
          config['token'] as String,
          cursor,
        );
        messages.sort(
          (a, b) => BigInt.parse(
            a['id'] as String,
          ).compareTo(BigInt.parse(b['id'] as String)),
        );
        var processed = 0;
        for (final message in messages) {
          _reportDiscord(
            DiscordSyncProgress(
              'Processing Discord requests',
              completed: processed,
              total: messages.length,
            ),
          );
          final messageId = message['id'] as String;
          if (BigInt.parse(messageId) <= BigInt.parse(cursor)) continue;
          Map<String, Object?>? session;
          for (final row in candidates) {
            final connection = DiscordConnection.decode(
              row.read<String>('endpoint'),
            );
            if (connection.webhook.pathSegments[2] == message['webhook_id']) {
              session = row.data;
              break;
            }
          }
          if (session != null) await _processDiscordMessage(session, message);
          cursor = messageId;
          await relaySecrets.write('cursor:$channel', cursor);
          processed++;
          _reportDiscord(
            DiscordSyncProgress(
              'Processing Discord requests',
              completed: processed,
              total: messages.length,
            ),
          );
        }
        if (messages.length < 100) break;
      }
    } finally {
      _reportDiscord(const DiscordSyncProgress('idle'));
      _discordPolling = false;
    }
  }

  Future<void> _processDiscordMessage(
    Map<String, Object?> session,
    Map<String, dynamic> message,
  ) async {
    final id = session['id'] as String;
    final connection = DiscordConnection.decode(session['endpoint'] as String);
    Map<String, dynamic>? packet;
    try {
      packet = await discordApi.packet(message);
    } on FormatException {
      return;
    } on TypeError {
      return;
    }
    if (packet == null &&
        message['content'] == '' &&
        (message['attachments'] as List? ?? <Object>[]).isEmpty) {
      throw const LedgerException(
        'Discord is hiding message contents. Enable Message Content Intent for the bot, then retry the inbox.',
      );
    }
    if (packet == null ||
        packet['direction'] != 'request' ||
        packet['id'] != id) {
      return;
    }
    Map<String, dynamic> data;
    try {
      data = await cipher.open(
        packet,
        session['secret'] as String,
        'discord-request:$id:${connection.trip}',
      );
    } catch (_) {
      return;
    } // Ignore forged or corrupt packets without blocking the inbox.
    final request = data['request'];
    if (request is! String ||
        !Uuid.isValidUUID(fromString: request) ||
        data['trip'] != session['trip_id']) {
      return;
    }
    final response = <String, Object?>{'request': request};
    try {
      // Recheck permission even for reads, in case an invitation was revoked during a poll.
      final active = await _session(id);
      if (active['role'] != 'host' || active['trip_id'] != connection.trip) {
        return;
      }
      final expiresAt = DiscordConnection.decode(
        active['endpoint'] as String,
      ).expiresAt;
      if (expiresAt != null) {
        // These timestamps come from Discord, never from the encrypted guest payload.
        // Checking the last edit also prevents reusing an old message after expiry.
        final timestamp = message['edited_timestamp'] ?? message['timestamp'];
        final receivedAt = timestamp is String
            ? DateTime.tryParse(timestamp)
            : null;
        if (receivedAt == null || !receivedAt.isBefore(expiresAt)) {
          throw const LedgerException(
            'This invitation has expired. Ask the host for a new invitation.',
          );
        }
      }
      if (data['action'] == 'add') {
        final submission = data['submission'];
        if (submission is! String ||
            !Uuid.isValidUUID(fromString: submission)) {
          throw const FormatException();
        }
        response['saved'] = await TransactionRepository(db).save(
          _input(data['expense'] as Map<String, dynamic>),
          sharedTripId: connection.trip,
          sharedSessionId: id,
          sharedRequestId: submission,
        );
        // One-way browser deliveries need no host reply. An expired invitation
        // must never receive a fresh ledger snapshot, even after a valid late import.
        if (data['reply'] == false ||
            (expiresAt != null && !_clock().isBefore(expiresAt))) {
          return;
        }
      } else if (data['action'] == 'read' &&
          expiresAt != null &&
          !_clock().isBefore(expiresAt)) {
        throw const LedgerException(
          'This invitation has expired. Ask the host for a new invitation.',
        );
      } else if (data['action'] != 'read') {
        throw const FormatException();
      }
      response['snapshot'] = await snapshot(connection.trip);
    } on LedgerException catch (e) {
      response['error'] = e.message;
    } on FormatException {
      response['error'] =
          'This expense is invalid. Check its fields and try again.';
    } on TypeError {
      response['error'] =
          'This expense is invalid. Check its fields and try again.';
    }
    if (data['reply'] == false) {
      return;
    }
    final encrypted = await cipher.seal(
      response,
      session['secret'] as String,
      'discord-response:$id:$request',
    );
    await discordApi.reply(connection.webhook, message['id'] as String, {
      'direction': 'response',
      'id': id,
      ...encrypted,
    });
  }

  Future<Map<String, dynamic>> _sendDiscord(
    Map<String, Object?> session,
    Map<String, Object?> data,
  ) async {
    final id = session['id'] as String;
    if (await relaySecrets.read('blocked:$id') != null) {
      throw const LedgerException(
        'This sharing connection is no longer available. Contact the host.',
      );
    }
    final connection = DiscordConnection.decode(session['endpoint'] as String);
    if (connection.expired(_clock())) {
      throw const LedgerException(
        'This invitation has expired. Ask the host for a new invitation.',
      );
    }
    final slot = 'request:$id:${data['submission'] ?? 'read'}';
    var raw = await relaySecrets.read(slot);
    try {
      if (raw == null) {
        final requestId = const Uuid().v4();
        final encrypted = await cipher.seal(
          {...data, 'request': requestId, 'trip': connection.trip},
          session['secret'] as String,
          'discord-request:$id:${connection.trip}',
        );
        final message = await discordApi.post(connection.webhook, {
          'direction': 'request',
          'id': id,
          ...encrypted,
        });
        raw = jsonEncode({'message': message['id'], 'request': requestId});
        await relaySecrets.write(slot, raw);
      }
      final sent = jsonDecode(raw) as Map;
      final message = await discordApi.get(
        connection.webhook,
        sent['message'] as String,
      );
      final packet = await discordApi.packet(message);
      if (packet == null || packet['direction'] != 'response') {
        throw const LedgerException(
          'Sent to relay. Waiting for the host to open the app and process it. Tap Sync again later.',
        );
      }
      final response = await cipher.open(
        packet,
        session['secret'] as String,
        'discord-response:$id:${sent['request']}',
      );
      if (packet['id'] != id || response['request'] != sent['request']) {
        throw const FormatException();
      }
      if (response['error'] is String) {
        await relaySecrets.write(slot, null);
        throw LedgerException(response['error'] as String);
      }
      // Keep successful add acknowledgements until sync removes the queue entry.
      // A read request can be replaced after its snapshot has been received.
      if (data['action'] == 'read') await relaySecrets.write(slot, null);
      return response;
    } on DiscordUnavailable {
      try {
        await discordApi.request('GET', connection.webhook);
      } on DiscordUnavailable {
        await relaySecrets.write('blocked:$id', '1');
        throw const LedgerException(
          'This sharing connection is no longer available. Contact the host.',
        );
      }
      await relaySecrets.write(slot, null);
      throw const LedgerException(
        'The relay message was removed. Your expense is kept; tap Sync to retry.',
      );
    }
  }
}

String _discordInvitationCode(
  String id,
  String key,
  String endpoint,
  String name, {
  String? bootstrap,
}) =>
    'expense-trip:${base64UrlEncode(utf8.encode(jsonEncode({'version': 2, 'id': id, 'key': key, 'endpoint': endpoint, 'name': name, 'bootstrap': ?bootstrap})))}';

void _validateGuestPage(Uri page) {
  if (page.scheme != 'https' ||
      page.host.isEmpty ||
      page.userInfo.isNotEmpty ||
      page.hasQuery ||
      page.hasFragment ||
      page.port != 443) {
    throw const LedgerException(
      'Configure an HTTPS guest page URL without a query or fragment.',
    );
  }
}
