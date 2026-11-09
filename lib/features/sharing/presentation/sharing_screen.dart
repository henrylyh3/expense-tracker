import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/money/money.dart';
import '../../../core/dates/calendar_date.dart';
import '../../../core/sharing/sharing_service.dart';
import '../../../core/sharing/discord_api.dart';
import 'discord_settings.dart';

final sharingServiceProvider = Provider<SharingService>((ref) {
  final service = SharingService(ref.watch(databaseProvider));
  ref.onDispose(() => unawaited(service.stopHost()));
  return service;
});
final sharedSessionsProvider = StreamProvider(
  (ref) => ref.watch(sharingServiceProvider).watchSessions(),
  retry: (count, error) => null,
);
final sharedPendingProvider =
    StreamProvider.family<List<Map<String, Object?>>, String>((ref, id) {
      final db = ref.watch(databaseProvider);
      return db
          .customSelect(
            'SELECT id, payload FROM shared_pending WHERE session_id = ? ORDER BY created_at, id',
            variables: [Variable.withString(id)],
            readsFrom: {db.sharedPending},
          )
          .watch()
          .map((rows) => [for (final row in rows) row.data]);
    }, retry: (count, error) => null);

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({this.sessionId, super.key});
  final String? sessionId;
  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is LedgerException
              ? error.message
              : error is DiscordUnavailable
              ? 'Discord connection is no longer available. Check the channel and bot access.'
              : 'Unable to sync. Check your connection and sharing settings, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(sharingServiceProvider);
    final sessions = ref.watch(sharedSessionsProvider);
    final active =
        ref.watch(activeTripProvider).asData?.value ?? personalTripId;
    final trips = ref.watch(tripsProvider).asData?.value ?? [];
    final tripName =
        trips.where((trip) => trip.id == active).firstOrNull?.name ??
        'Personal';
    final selected = sessions.asData?.value
        .where((row) => row['id'] == widget.sessionId)
        .firstOrNull;
    return PopScope(
      canPop: !_busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Shared trips',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'The host keeps the ledger. Share over local Wi-Fi or through encrypted internet messages relayed by Discord. Keep the host app open to process expenses. Guests can queue offline after their first sync.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!),
            ),
          if (widget.sessionId == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Internet sharing',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ref.watch(discordSettingsProvider).asData?.value == null
                          ? 'Set up your private Discord connection once for all trips.'
                          : 'Discord connection saved. Works across different networks.',
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('Configure internet sharing'),
                      onPressed: _busy
                          ? null
                          : () async {
                              final saved = await showDialog<bool>(
                                context: context,
                                builder: (_) =>
                                    DiscordSettingsDialog(service: service),
                              );
                              if (saved == true) {
                                ref.invalidate(discordSettingsProvider);
                              }
                            },
                    ),
                    if (ref.watch(discordSettingsProvider).asData?.value !=
                        null) ...[
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final guest = await _text(
                                  context,
                                  'Invite internet guest',
                                  'Guest name',
                                );
                                if (guest == null) return;
                                final code = await service.inviteDiscord(
                                  active,
                                  guest,
                                );
                                if (!context.mounted) return;
                                await _showInvitation(context, code);
                              }),
                        child: const Text('Invite guest over internet'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await service.pollDiscord();
                                if (mounted) {
                                  setState(
                                    () =>
                                        _message = 'Internet inbox processed.',
                                  );
                                }
                              }),
                        child: const Text('Process internet inbox'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await service.clearDiscord();
                                ref.invalidate(discordSettingsProvider);
                              }),
                        child: const Text('Remove internet connection'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Host trip: $tripName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Change the default trip in Trips and profiles to host a different trip.',
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (service.hosting) {
                        await service.stopHost();
                      } else {
                        await service.startHost();
                      }
                      if (mounted) setState(() {});
                    }),
              icon: Icon(
                service.hosting
                    ? Icons.stop_circle_outlined
                    : Icons.wifi_tethering,
              ),
              label: Text(service.hosting ? 'Stop hosting' : 'Start hosting'),
            ),
            if (service.hosting)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final addresses = await service.hostAddresses();
                        if (!context.mounted) return;
                        final guest = await _text(
                          context,
                          'Invite a guest',
                          'Guest name',
                        );
                        if (guest == null || !context.mounted) return;
                        final endpoint = await _text(
                          context,
                          'Host address',
                          'Host Wi-Fi / hotspot address',
                          initial: addresses.isEmpty
                              ? ''
                              : 'http://${addresses.first}:${service.port}',
                        );
                        if (endpoint == null || !context.mounted) return;
                        final code = await service.invite(
                          active,
                          guest,
                          endpoint,
                        );
                        if (!context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Guest invitation'),
                            scrollable: true,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Share this code privately with this guest. It grants access to this trip. Create a separate invitation for each person.',
                                ),
                                const SizedBox(height: 12),
                                SelectableText(code),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: code),
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                },
                                child: const Text('Copy invitation'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        );
                      }),
                child: const Text('Invite guest to this trip'),
              ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final code = await _text(
                        context,
                        'Join shared trip',
                        'Paste invitation',
                      );
                      if (code != null) await service.join(code.trim());
                    }),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Join using invitation'),
            ),
            const Divider(),
            const Text(
              'Guests and joined trips',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...sessions.when(
              data: (items) => [
                for (final item in items)
                  ListTile(
                    title: Text(item['name'] as String),
                    subtitle: Text(
                      item['role'] == 'host'
                          ? 'Invited guest · access can be revoked'
                          : 'Joined trip · tap to sync or add expenses',
                    ),
                    onTap: _busy
                        ? null
                        : () => context.push('/settings/sharing/${item['id']}'),
                  ),
              ],
              loading: () => [const LinearProgressIndicator()],
              error: (_, _) => [
                TextButton(
                  onPressed: () => ref.invalidate(sharedSessionsProvider),
                  child: const Text('Retry invitations'),
                ),
              ],
            ),
          ] else if (selected == null) ...[
            const Text('Invitation removed.'),
          ] else
            ..._session(context, service, selected),
        ],
      ),
    );
  }

  List<Widget> _session(
    BuildContext context,
    SharingService service,
    Map<String, Object?> session,
  ) {
    final id = session['id'] as String;
    final guest = session['role'] == 'guest';
    final internet = DiscordConnection.matches(session['endpoint'] as String);
    final cache = session['cache'] as String?;
    final data = cache == null
        ? null
        : jsonDecode(cache) as Map<String, dynamic>;
    final pending = ref.watch(sharedPendingProvider(id)).asData?.value ?? [];
    return [
      const SizedBox(height: 16),
      Text(
        data?['name'] as String? ?? session['name'] as String,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (guest) ...[
        if (internet)
          const Text(
            'Send queued expenses, then sync again after the host processes them. Pending items remain here until confirmed.',
          ),
        Text(
          internet
              ? 'Internet sharing · encrypted relay via Discord'
              : 'Host address: ${session['endpoint']}',
        ),
        Text('${pending.length} expenses waiting to sync'),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(() => service.sync(id)),
          icon: const Icon(Icons.sync),
          label: const Text('Sync with host'),
        ),
        OutlinedButton.icon(
          onPressed: _busy || data == null
              ? null
              : () => _run(() async {
                  final expense = await _expense(context, data);
                  if (expense != null) {
                    await service.queue(id, expense);
                    if (mounted) {
                      setState(
                        () => _message =
                            'Expense queued. Sync with the host to submit it.',
                      );
                    }
                  }
                }),
          icon: const Icon(Icons.add),
          label: const Text('Add shared expense'),
        ),
        if (!internet)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final endpoint = await _text(
                      context,
                      'Update host address',
                      'Host Wi-Fi / hotspot address',
                      initial: session['endpoint'] as String,
                    );
                    if (endpoint != null) {
                      await service.updateEndpoint(id, endpoint.trim());
                    }
                  }),
            child: const Text('Update host address'),
          ),
        for (final item in pending)
          ListTile(
            title: Text(
              'Queued: ${(jsonDecode(item['payload'] as String) as Map)['amount']} ${(jsonDecode(item['payload'] as String) as Map)['currency']}',
            ),
            subtitle: Text(
              (jsonDecode(item['payload'] as String) as Map)['date'] as String,
            ),
            trailing: IconButton(
              tooltip: 'Discard queued expense',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Discard queued expense?'),
                          content: const Text(
                            'If already sent, the host may still save this expense. Discarding only removes the local queue entry; it does not cancel a sent message or delete a saved expense.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        await service.discardPending(id, item['id'] as String);
                      }
                    }),
            ),
          ),
        if (data != null) ...[
          Text(
            'Host total · ${Money.fromMinor(minorUnits: int.parse(data['total_myr_minor'] as String), currencyCode: 'MYR', decimalPlaces: 2).format()}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${data['count']} expenses · Last sync ${data['synced_at']}'),
          const Text(
            'Queued expenses are not included until the host accepts them.',
          ),
          for (final row in data['recent'] as List)
            ListTile(
              title: Text('${row['category']} · ${row['amount']}'),
              subtitle: Text(
                '${row['date']}${row['note'] == null ? '' : '\n${row['note']}'}',
              ),
            ),
        ],
      ] else
        const Text(
          'This invitation grants read and add access to one trip. Removing it immediately revokes access. Existing submitted expenses stay in your ledger.',
        ),
      TextButton(
        onPressed: _busy
            ? null
            : () => _run(() async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      guest ? 'Leave shared trip?' : 'Revoke guest access?',
                    ),
                    content: Text(
                      guest
                          ? 'This removes this invitation, its cached view and any unsent expenses from this device.'
                          : 'This guest will no longer be able to sync using this invitation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (yes == true) {
                  await service.revoke(id);
                  if (context.mounted) context.pop();
                }
              }),
        child: Text(
          guest ? 'Leave trip and remove local copy' : 'Revoke invitation',
        ),
      ),
    ];
  }
}

Future<String?> _text(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
}) {
  var value = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        maxLines: null,
        decoration: InputDecoration(labelText: label),
        onChanged: (text) => value = text,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, value),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

Future<Map<String, Object?>?> _expense(
  BuildContext context,
  Map<String, dynamic> snapshot,
) {
  final categories = (snapshot['categories'] as List)
      .cast<Map<String, dynamic>>();
  final currencies = (snapshot['currencies'] as List)
      .cast<Map<String, dynamic>>();
  if (categories.isEmpty || currencies.isEmpty) return Future.value(null);
  final form = GlobalKey<FormState>();
  var category =
      categories.firstWhere(
            (row) => row['id'] == 'seed-food',
            orElse: () => categories.first,
          )['id']
          as String;
  var currency =
      currencies.firstWhere(
            (row) => row['id'] == snapshot['default_currency'],
            orElse: () => currencies.first,
          )['id']
          as String;
  var amount = '';
  var note = '';
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Shared expense'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final row in categories)
                    DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(row['name'] as String),
                    ),
                ],
                onChanged: (value) => category = value!,
              ),
              DropdownButtonFormField<String>(
                initialValue: currency,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: [
                  for (final row in currencies)
                    DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text('${row['code']} · ${row['name']}'),
                    ),
                ],
                onChanged: (value) => setState(() => currency = value!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => amount = value,
                validator: (value) {
                  try {
                    final c = currencies.firstWhere(
                      (row) => row['id'] == currency,
                    );
                    Money.parseExpense(
                      value ?? '',
                      currencyCode: c['code'] as String,
                      decimalPlaces: c['precision'] as int,
                    );
                    return null;
                  } on LedgerException catch (error) {
                    return error.message;
                  }
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLength: 2000,
                onChanged: (value) => note = value,
              ),
              Text('Date: ${CalendarDate.today()}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, {
                  'category': category,
                  'currency_id': currency,
                  'amount': amount,
                  'date': CalendarDate.today().toString(),
                  'note': note,
                });
              }
            },
            child: const Text('Queue expense'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showInvitation(
  BuildContext context,
  String code,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Guest invitation'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Share privately with this guest. This invitation grants read and add access to one trip. Do not share it with others.',
        ),
        const SizedBox(height: 12),
        SelectableText(code),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Copy invitation'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  ),
);
