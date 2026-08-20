import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'analyzer_api.dart';

/// Device registration for push.
///
/// The app only ever *receives*: alerts are sent server-side by whatever wrote
/// the alert row, after it has passed the severity and quiet-hours gates. This
/// class exists to hand the server a token, to drop it on sign-out, and to say
/// where to go when the manager taps the notification.
///
/// Everything here fails soft. A manager who declines notifications, or whose
/// phone has no Play Services, must still get a working app — he just has to
/// open it himself.
class PushService {
  PushService(this._api);

  final AnalyzerApi _api;

  /// Set by the app so a tapped notification can change tabs. Kept as a
  /// callback rather than a navigator reference because a push can arrive
  /// before any route exists — the app may be launching from cold.
  void Function()? onAlertOpened;

  /// Only true once Firebase actually initialised. Web has no Firebase config
  /// wired up this round, and an uninitialised plugin throws on first use.
  bool _available = false;

  bool _listening = false;

  /// The token currently registered with the server, so sign-out can remove
  /// exactly that row rather than guessing.
  String? _token;

  /// Called from `main()` once `Firebase.initializeApp` has succeeded.
  void markAvailable() => _available = true;

  /// Ask for permission and register this install.
  ///
  /// Called when a session exists, not at boot: a token is only addressable
  /// once the server knows which user — and therefore which org — it belongs
  /// to. On Android 13+ `requestPermission` is what raises the
  /// POST_NOTIFICATIONS system prompt.
  Future<void> register() async {
    if (!_available) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;
      await _api.registerDevice(token, _platform);
      _token = token;

      if (!_listening) {
        _listening = true;
        // Tokens rotate. A stale one means silent alerts, which is the worst
        // failure this product can have.
        messaging.onTokenRefresh.listen((refreshed) {
          _token = refreshed;
          _api.registerDevice(refreshed, _platform).catchError((Object error) {
            dev.log('token refresh registration failed: $error', name: 'push');
          });
        });

        // Tapped while the app was in the background.
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

        // Tapped while the app was not running at all: the message that
        // started the process is waiting here exactly once.
        messaging.getInitialMessage().then((message) {
          if (message != null) _handleOpened(message);
        });
      }
    } catch (error) {
      dev.log('push registration failed: $error', name: 'push');
    }
  }

  /// Stop this phone receiving another org's alerts.
  ///
  /// Must run while the session token is still set — the DELETE is
  /// authenticated. The FCM token itself is left alone: the next sign-in
  /// re-registers the same one, and revoking it would only churn a value the
  /// server no longer has a row for.
  Future<void> unregister() async {
    final token = _token;
    _token = null;
    if (token == null) return;

    try {
      await _api.deleteDevice(token);
    } catch (error) {
      // A failed delete is not worth blocking sign-out over; the server drops
      // tokens that FCM reports as gone anyway.
      dev.log('device removal failed: $error', name: 'push');
    }
  }

  void _handleOpened(RemoteMessage message) {
    // `data.alert_id` is already in the payload the API sends, so deep-linking
    // to the specific alert is a later change with no server work. Landing on
    // the feed is what the notification promised.
    dev.log(
      'opened from notification: ${message.data['alert_id'] ?? 'unknown'}',
      name: 'push',
    );
    onAlertOpened?.call();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
