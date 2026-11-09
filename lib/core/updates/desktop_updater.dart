import 'dart:io';

import 'package:auto_updater/auto_updater.dart';

/// Native updaters verify signed payloads and ask before installing/restarting.
/// Release builds opt in only after embedding their platform public key.
class DesktopUpdater {
  DesktopUpdater({
    this.feedUrl = const String.fromEnvironment('DESKTOP_UPDATE_FEED_URL'),
    this.signingConfigured = const bool.fromEnvironment(
      'DESKTOP_UPDATE_SIGNING_CONFIGURED',
    ),
    bool? supported,
    Future<void> Function(String)? setFeed,
    Future<void> Function(int)? setInterval,
    Future<void> Function(bool)? checkNative,
  }) : _supported = supported ?? (Platform.isMacOS || Platform.isWindows),
       _setFeed = setFeed ?? ((url) => autoUpdater.setFeedURL(url)),
       _setInterval =
           setInterval ??
           ((seconds) => autoUpdater.setScheduledCheckInterval(seconds)),
       _checkNative =
           checkNative ??
           ((background) =>
               autoUpdater.checkForUpdates(inBackground: background));

  final String feedUrl;
  final bool signingConfigured;
  final bool _supported;
  final Future<void> Function(String) _setFeed;
  final Future<void> Function(int) _setInterval;
  final Future<void> Function(bool) _checkNative;
  bool _initialized = false;
  Future<void>? _active;

  Future<void> check({bool background = false}) =>
      _active ??= _run(background).whenComplete(() => _active = null);

  Future<void> _run(bool background) async {
    if (!_supported) return;
    final uri = Uri.tryParse(feedUrl);
    if (!signingConfigured ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      if (background) return;
      throw StateError(
        'Desktop updates require a signed HTTPS feed configured in this build.',
      );
    }
    if (!_initialized) {
      await _setFeed(feedUrl);
      // Checks belong to the app's open/resume lifecycle, not a scheduler.
      await _setInterval(0);
      _initialized = true;
    }
    await _checkNative(background);
  }
}

final desktopUpdater = DesktopUpdater();
