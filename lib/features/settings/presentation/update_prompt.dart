import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/updates/update_service.dart';
import '../../../core/updates/desktop_updater.dart';

// Package installation follows the running OS, independently of UI styling.
final updateTargetPlatformProvider = Provider<TargetPlatform?>((ref) {
  if (Platform.isAndroid) return TargetPlatform.android;
  if (Platform.isMacOS) return TargetPlatform.macOS;
  if (Platform.isWindows) return TargetPlatform.windows;
  return null;
});
final updateSupportedProvider = Provider<bool>(
  (ref) => ref.watch(updateTargetPlatformProvider) != null,
);

bool _desktopTarget(TargetPlatform? target) =>
    target == TargetPlatform.macOS || target == TargetPlatform.windows;
final updateClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class CheckUpdatesButton extends ConsumerWidget {
  const CheckUpdatesButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Check for updates',
    icon: const Icon(Icons.system_update_alt),
    onPressed: !ref.watch(updateSupportedProvider)
        ? null
        : () async {
            if (_desktopTarget(ref.read(updateTargetPlatformProvider))) {
              try {
                await desktopUpdater.check();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not check for desktop updates. Check your connection or install the latest desktop release from GitHub.',
                      ),
                    ),
                  );
                }
              }
              return;
            }
            await showDialog<void>(
              context: context,
              builder: (_) => const _ManualUpdateCheck(),
            );
          },
  );
}

class _ManualUpdateCheck extends ConsumerStatefulWidget {
  const _ManualUpdateCheck();
  @override
  ConsumerState<_ManualUpdateCheck> createState() => _ManualUpdateCheckState();
}

class _ManualUpdateCheckState extends ConsumerState<_ManualUpdateCheck> {
  late Future<UpdateRelease?> _check;
  @override
  void initState() {
    super.initState();
    _check = ref.read(updateServiceProvider).check();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UpdateRelease?>(
    future: _check,
    builder: (context, state) {
      if (state.connectionState == ConnectionState.done &&
          !state.hasError &&
          state.data != null) {
        return UpdatePrompt(release: state.data!);
      }
      final loading = state.connectionState != ConnectionState.done;
      return AlertDialog(
        title: Text(
          loading
              ? 'Checking for updates'
              : state.hasError
              ? 'Could not check for updates'
              : 'You’re up to date',
        ),
        content: loading
            ? const LinearProgressIndicator()
            : Text(
                state.hasError
                    ? 'Check your internet connection and try again. GitHub may be temporarily unavailable.'
                    : 'You have the latest published version.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (state.hasError)
            FilledButton(
              onPressed: () => setState(() {
                _check = ref.read(updateServiceProvider).check();
              }),
              child: const Text('Retry'),
            ),
        ],
      );
    },
  );
}

class UpdateCheckOnOpen extends ConsumerStatefulWidget {
  const UpdateCheckOnOpen({
    required this.ready,
    required this.busy,
    required this.navigatorContext,
    required this.child,
    this.canPrompt,
    super.key,
  });
  final bool ready;
  final bool busy;
  final BuildContext? Function() navigatorContext;
  final Widget child;
  final bool Function()? canPrompt;
  @override
  ConsumerState<UpdateCheckOnOpen> createState() => _UpdateCheckOnOpenState();
}

class _UpdateCheckOnOpenState extends ConsumerState<UpdateCheckOnOpen>
    with WidgetsBindingObserver {
  bool _attempted = false;
  bool _queued = false;
  bool _showing = false;
  UpdateRelease? _pending;
  DateTime? _lastCheck;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_showing &&
        (_lastCheck == null ||
            ref.read(updateClockProvider)().difference(_lastCheck!) >=
                const Duration(minutes: 5))) {
      _attempted = false;
      _schedule();
    }
  }

  @override
  void didUpdateWidget(covariant UpdateCheckOnOpen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (!widget.ready || widget.busy || !ref.read(updateSupportedProvider)) {
      return;
    }
    _offerPending();
    if (_attempted) return;
    _attempted = true;
    _lastCheck = ref.read(updateClockProvider)();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_desktopTarget(ref.read(updateTargetPlatformProvider))) {
        try {
          await desktopUpdater.check(background: true);
        } catch (_) {
          /* Offline never blocks the ledger. */
        }
        return;
      }
      try {
        final release = await ref.read(updateServiceProvider).check();
        if (!mounted || release == null) return;
        _pending = release;
        _offerPending();
      } catch (_) {
        // Offline, unavailable, and rate-limited checks never block the ledger.
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _offerPending() {
    if (_pending == null || _queued || _showing) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _queued = false;
      if (!mounted ||
          _pending == null ||
          !widget.ready ||
          widget.busy ||
          !(widget.canPrompt?.call() ?? true)) {
        return;
      }
      final service = ref.read(updateServiceProvider);
      if (_pending!.versionCode == service.deferredVersion) {
        _pending = null;
        return;
      }
      final context = widget.navigatorContext();
      if (context == null ||
          !context.mounted ||
          Navigator.of(context, rootNavigator: true).canPop()) {
        return;
      }
      final release = _pending!;
      _pending = null;
      _showing = true;
      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdatePrompt(release: release),
        );
      } finally {
        _showing = false;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UpdatePrompt extends ConsumerStatefulWidget {
  const UpdatePrompt({required this.release, super.key});
  final UpdateRelease release;
  @override
  ConsumerState<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<UpdatePrompt>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _downloading = false;
  bool _waitingPermission = false;
  double _progress = 0;
  String? _path;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingPermission && !_busy) {
      _resumePermission();
    }
  }

  Future<void> _resumePermission() async {
    try {
      if (await ref.read(updateServiceProvider).canInstall() && mounted) {
        _waitingPermission = false;
        await _install();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not open the updater. Try again.');
      }
    }
  }

  String _error(Object error) => error is PlatformException
      ? error.message ?? 'Android could not install the update. Try again.'
      : error is UpdateCancelled
      ? 'Download cancelled. Your current app is unchanged.'
      : 'Could not download or verify the update. Check your connection and try again.';

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _downloading = true;
      _message = null;
      _progress = 0;
    });
    try {
      final path = await ref.read(updateServiceProvider).download(
        widget.release,
        (received, total) {
          if (mounted) setState(() => _progress = received / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _path = path;
        _busy = false;
        _downloading = false;
      });
      await _install();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _downloading = false;
          _message = _error(error);
        });
      }
    }
  }

  Future<void> _install() async {
    if (_path == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(updateServiceProvider);
      if (!await service.canInstall()) {
        _waitingPermission = true;
        if (mounted) {
          setState(
            () => _message =
                'Allow updates from Expense Tracker in Android Settings, then return here.',
          );
        }
        await service.requestPermission();
      } else {
        _waitingPermission = false;
        await service.install(widget.release, _path!);
        if (mounted) {
          setState(
            () => _message =
                'Confirm Update in Android’s installer. If you cancelled, you can try again.',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _error(error);
          if (error is PlatformException &&
              error.code == 'update_verification_failed') {
            _path = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense Tracker ${widget.release.version}'),
            const SizedBox(height: 8),
            Text(
              '${(widget.release.size / 1048576).toStringAsFixed(1)} MB · Your expenses stay on this device.',
            ),
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress == 1
                    ? 'Verifying update…'
                    : 'Downloading… ${(_progress * 100).round()}%',
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
            if (widget.release.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(widget.release.notes),
            ],
          ],
        ),
      ),
      actions: _downloading
          ? [
              TextButton(
                onPressed: () => ref.read(updateServiceProvider).cancel(),
                child: const Text('Cancel download'),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        ref.read(updateServiceProvider).deferredVersion =
                            widget.release.versionCode;
                        Navigator.pop(context);
                      },
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : _path == null
                    ? _download
                    : _install,
                child: Text(
                  _path == null
                      ? 'Update now'
                      : _waitingPermission
                      ? 'Allow updates'
                      : 'Install update',
                ),
              ),
            ],
    ),
  );
}
