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
import '../../../core/sharing/shared_trip_total.dart';
import '../../../core/sharing/discord_api.dart';
import '../../../core/sharing/guest_web.dart';
import 'discord_settings.dart';

final sharingServiceProvider = Provider<SharingService>((ref) {
  final service = SharingService(ref.watch(databaseProvider));
  ref.onDispose(() => unawaited(service.dispose()));
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
    final active = ref.watch(activeTripProvider).asData?.value;
    final trips = ref.watch(tripsProvider).asData?.value ?? [];
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
            'The host keeps the ledger. Encrypted invitations let guests send expenses over the internet. Open the host app to import them.',
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
                        onPressed: _busy || active == null || trips.isEmpty
                            ? null
                            : () => _run(
                                () =>
                                    _invite(service, trips, active, web: false),
                              ),
                        child: const Text('Invite guest over internet'),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('Invite guest by web link'),
                        onPressed:
                            _busy ||
                                active == null ||
                                trips.isEmpty ||
                                guestWebUrl.isEmpty
                            ? null
                            : () => _run(
                                () =>
                                    _invite(service, trips, active, web: true),
                              ),
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
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final code = await _text(
                        context,
                        'Join shared trip',
                        'Paste invitation',
                      );
                      if (code != null) {
                        await service.join(code.trim(), internetOnly: true);
                      }
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

  Future<void> _invite(
    SharingService service,
    List<({String id, String name})> trips,
    String active, {
    required bool web,
  }) async {
    final details = await showDialog<({String guest, String trip, int days})>(
      context: context,
      builder: (_) => _InvitationDialog(trips: trips, active: active, web: web),
    );
    if (details == null || !mounted) return;
    final code = web
        ? await service.inviteDiscordWeb(
            details.trip,
            details.guest,
            Uri.parse(guestWebUrl),
            validFor: Duration(days: details.days),
          )
        : await service.inviteDiscord(details.trip, details.guest);
    if (!mounted) return;
    await _showInvitation(
      context,
      code,
      expiryLabel: web
          ? details.days == 1
                ? 'Expires after 24 hours. You can revoke access sooner.'
                : 'Expires after ${details.days} days. You can revoke access sooner.'
          : null,
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
        data?['name'] as String? ??
            (guest ? 'Shared trip' : session['name'] as String),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (!internet)
        const Text(
          'This invitation used local sharing. Create a new internet invitation to share this trip.',
        ),
      if (guest) ...[
        Text('Guest: ${session['name']}'),
        if (internet)
          const Text(
            'Send queued expenses, then sync again after the host processes them. Pending items remain here until confirmed.',
          ),
        Text('${pending.length} expenses waiting to sync'),
        FilledButton.icon(
          onPressed: _busy || !internet
              ? null
              : () => _run(() => service.sync(id)),
          icon: const Icon(Icons.sync),
          label: const Text('Sync with host'),
        ),
        OutlinedButton.icon(
          onPressed: _busy || !internet || data == null
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
            'Host total · ${formatSharedTripTotal(data)}',
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

Future<String?> _text(BuildContext context, String title, String label) {
  var value = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
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
  String code, {
  String? expiryLabel,
}) => showDialog<void>(
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
        if (expiryLabel != null) ...[
          Text(expiryLabel),
          const SizedBox(height: 12),
        ],
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

class _InvitationDialog extends StatefulWidget {
  const _InvitationDialog({
    required this.trips,
    required this.active,
    required this.web,
  });

  final List<({String id, String name})> trips;
  final String active;
  final bool web;

  @override
  State<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<_InvitationDialog> {
  final _name = TextEditingController();
  int _days = 7;
  late String _trip = widget.trips.any((trip) => trip.id == widget.active)
      ? widget.active
      : widget.trips.first.id;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.web ? 'Invite a web guest' : 'Invite internet guest'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Guest name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _trip,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Trip or profile'),
          items: [
            for (final trip in widget.trips)
              DropdownMenuItem(
                value: trip.id,
                child: Text(trip.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _trip = value!),
        ),
        if (widget.web) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _days,
            decoration: const InputDecoration(
              labelText: 'Access expires after',
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('24 hours')),
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
            ],
            onChanged: (value) => setState(() => _days = value!),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                guest: _name.text.trim(),
                trip: _trip,
                days: _days,
              )),
        child: Text(widget.web ? 'Create link' : 'Create invitation'),
      ),
    ],
  );
}
