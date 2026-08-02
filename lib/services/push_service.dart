import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers this device for push and keeps its FCM token in Firestore, so
/// whatever writes the alert document can fan the alert out to every signed-in
/// manager's phone.
///
/// **SCOPE: this class only receives.** Nothing in the app sends a
/// notification — the send is server-side (n8n, or a Cloud Function). A closed
/// iOS app cannot poll Firestore, which is the whole reason this exists; the
/// chime in `NotificationSound` only ever covered the foreground case.
///
/// Nothing here throws. Push is a convenience on top of the alerts stream, and
/// a device that fails to register must still be able to use the app.
class PushService {
  PushService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  /// One document per device install. n8n reads the whole collection and
  /// sends to every token in it.
  static const String tokensCollection = 'device_tokens';

  static const String _deviceIdKey = 'push_device_id';

  /// Web needs a VAPID key and a service worker that this project does not
  /// ship, and the requirement is phones. Registering there would throw on
  /// every load for no benefit.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  String? _deviceId;
  String? _email;

  /// Asks for notification permission and records the token for [email].
  ///
  /// Call on sign-in and on session restore. Safe to call repeatedly — the
  /// token document is keyed by a stable per-install id, so re-registering
  /// updates one row rather than accumulating stale ones.
  Future<void> registerFor(String email) async {
    if (!_supported) return;
    _email = email;
    try {
      // iOS shows the system prompt here. Denying is a normal outcome, not an
      // error — the user simply gets no banners.
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PushService: notifications denied by user');
        return;
      }

      // On iOS the FCM token is only issued once APNs has handed Firebase a
      // device token. Asking too early returns null rather than failing, so a
      // null here means "not ready yet", and onTokenRefresh delivers it later.
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('PushService: no FCM token yet (APNs not ready)');
        return;
      }
      await _storeToken(token);
    } catch (e) {
      debugPrint('PushService.registerFor failed: $e');
    }
  }

  /// Starts listening for token rotation. FCM reissues tokens on reinstall,
  /// restore-from-backup and occasionally at random; a device whose token
  /// rotated silently stops receiving until the new one is stored.
  void listenForTokenRefresh() {
    if (!_supported) return;
    _messaging.onTokenRefresh.listen(
      (token) async {
        if (_email == null) return;
        await _storeToken(token);
      },
      onError: (Object e) => debugPrint('PushService: token refresh error: $e'),
    );
  }

  Future<void> _storeToken(String token) async {
    final email = _email;
    if (email == null) return;
    try {
      final id = await _resolveDeviceId();
      await _db.collection(tokensCollection).doc(id).set({
        'token': token,
        'email': email,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PushService._storeToken failed: $e');
    }
  }

  /// Drops this device's token so a signed-out phone stops receiving alerts
  /// for a company it no longer has access to.
  Future<void> unregister() async {
    _email = null;
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_deviceIdKey);
      if (id != null) {
        await _db.collection(tokensCollection).doc(id).delete();
      }
      // Invalidates the token itself, so a send to it fails fast server-side
      // instead of being delivered to a device that has signed out.
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('PushService.unregister failed: $e');
    }
  }

  /// A stable id for this install, so token rotation updates one row rather
  /// than leaving a trail of dead documents. Deliberately not the FCM token
  /// itself: tokens change, and they are too long and oddly-charactered to be
  /// comfortable document ids.
  Future<String> _resolveDeviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = _randomId();
      await prefs.setString(_deviceIdKey, id);
    }
    _deviceId = id;
    return id;
  }

  static String _randomId() {
    final r = Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
