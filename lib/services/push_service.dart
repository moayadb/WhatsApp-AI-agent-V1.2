import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'analyzer_api.dart';

/// Device registration for push.
///
/// The app only ever *receives*: alerts are sent server-side by whatever wrote
/// the alert row, after it has passed the severity and quiet-hours gates. This
/// class exists to hand the server a token and to drop it on sign-out.
class PushService {
  PushService(this._api);

  final AnalyzerApi _api;

  bool _listening = false;

  /// Ask for permission and register this install.
  ///
  /// Failure is never fatal: a manager who declines notifications must still
  /// get a working app, they just have to open it themselves.
  Future<void> register() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;
      await _api.registerDevice(token, _platform);

      if (!_listening) {
        _listening = true;
        // Tokens rotate. A stale one means silent alerts, which is the worst
        // failure this product can have.
        messaging.onTokenRefresh.listen((refreshed) {
          _api.registerDevice(refreshed, _platform).catchError((Object error) {
            dev.log('token refresh registration failed: $error', name: 'push');
          });
        });
      }
    } catch (error) {
      dev.log('push registration failed: $error', name: 'push');
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
