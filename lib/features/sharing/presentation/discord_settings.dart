import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/sharing/sharing_service.dart';
import 'sharing_screen.dart';

final discordSettingsProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => ref.watch(sharingServiceProvider).discordSettings(),
  retry: (count, error) => null,
);

class DiscordSyncOnOpen extends ConsumerStatefulWidget {
  const DiscordSyncOnOpen({
    required this.ready,
    required this.busy,
    required this.child,
    super.key,
  });
  final bool ready;
  final bool busy;
  final Widget child;
  @override
  ConsumerState<DiscordSyncOnOpen> createState() => _DiscordSyncOnOpenState();
}

class _DiscordSyncOnOpenState extends ConsumerState<DiscordSyncOnOpen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_sync()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_sync()));
  }

  @override
  void didUpdateWidget(covariant DiscordSyncOnOpen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) unawaited(_sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_sync());
  }

  Future<void> _sync() async {
    if (!mounted || !widget.ready || widget.busy || !_foreground) return;
    try {
      await ref.read(sharingServiceProvider).pollDiscord();
    } catch (_) {
      // Queues and cursor stay intact; Sharing shows the error on manual retry.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class DiscordSettingsDialog extends StatefulWidget {
  const DiscordSettingsDialog({required this.service, super.key});
  final SharingService service;
  @override
  State<DiscordSettingsDialog> createState() => _DiscordSettingsDialogState();
}

class _DiscordSettingsDialogState extends State<DiscordSettingsDialog> {
  final _channel = TextEditingController();
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _previousToken;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final config = await widget.service.discordSettings();
      if (!mounted) return;
      _channel.text = config?['channel'] as String? ?? '';
      _previousToken = config?['token'] as String?;
    } catch (_) {
      if (mounted) _error = 'Unable to open protected storage. Try again.';
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _channel.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Internet sharing setup'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set up once for all trips. Encrypted sync messages pass through your private Discord channel. Guests do not need Discord accounts.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _channel,
            enabled: !_busy && _loaded,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Discord channel ID',
              helperText:
                  'Discord Settings → Advanced → Developer Mode, then copy the text channel ID.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            enabled: !_busy && _loaded,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Bot token',
              helperText: _previousToken == null
                  ? 'Stored securely on this device. Never shared with guests.'
                  : 'Leave blank to keep the saved token.',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bot permissions: View Channel, Read Message History, Send Messages and Manage Webhooks. Enable Message Content Intent in the Discord Developer Portal. The app creates a separate webhook for each invitation.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep the host app open to process expenses. Both sides need internet. Discord credentials and invitations are excluded from ledger exports.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || !_loaded
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await widget.service.configureDiscord(
                      _channel.text,
                      _token.text.trim().isEmpty
                          ? _previousToken ?? ''
                          : _token.text,
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (error) {
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _error = error is LedgerException
                            ? error.message
                            : 'Unable to save the Discord connection.';
                      });
                    }
                  }
                },
          child: const Text('Verify and save'),
        ),
      ],
    ),
  );
}
