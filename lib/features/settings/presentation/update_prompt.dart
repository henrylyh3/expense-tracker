import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/updates/update_service.dart';

final updateSupportedProvider = Provider<bool>((ref) => Platform.isAndroid);

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

class _UpdateCheckOnOpenState extends ConsumerState<UpdateCheckOnOpen> {
  bool _attempted = false;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant UpdateCheckOnOpen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (_attempted ||
        !widget.ready ||
        widget.busy ||
        !ref.read(updateSupportedProvider)) {
      return;
    }
    _attempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final release = await ref.read(updateServiceProvider).check();
        if (!mounted || release == null) return;
        // Never interrupt a restore/reset or an editor opened while checking.
        final context = widget.navigatorContext();
        if (!widget.ready ||
            widget.busy ||
            context == null ||
            !context.mounted) {
          return;
        }
        if (!(widget.canPrompt?.call() ?? true)) {
          return;
        }
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdatePrompt(release: release),
        );
      } catch (_) {
        // Offline, unavailable, and rate-limited checks never block the ledger.
      }
    });
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
                onPressed: _busy ? null : () => Navigator.pop(context),
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
