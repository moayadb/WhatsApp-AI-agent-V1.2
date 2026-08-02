import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  // Positional rather than named because Dart forbids named parameters that
  // start with an underscore, and a public `push` field would leak a service
  // nothing outside this class should reach for.
  AuthProvider(this._service, [this._push]);

  final AuthService _service;

  /// Push registration is a session-lifecycle concern — a token is only useful
  /// while somebody is signed in — so it hangs off the same transitions as the
  /// session itself. Null in tests, where there is no Firebase to talk to.
  final PushService? _push;

  AppUser? _user;
  bool _restoring = true;
  bool _busy = false;
  String? _errorCode;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get restoring => _restoring;
  bool get busy => _busy;

  /// One of: null | 'invalid_credentials' | 'not_allowed' |
  /// 'too_many_attempts' | 'sign_in_failed'.
  String? get errorCode => _errorCode;
  String? get errorDetail => _service.lastError;

  /// Restores an existing Firebase session on startup.
  Future<void> restore() async {
    _user = await _service.restoreSession();
    _restoring = false;
    notifyListeners();
    // Re-register every launch: iOS reissues tokens on reinstall and on
    // restore-from-backup, and a stale token is silently undeliverable.
    await _afterSignIn();
  }

  /// Signs in against Firebase Auth. Nothing is verified locally — the
  /// service hands both values straight to Firebase and reports what it says.
  Future<void> signIn(String username, String password) async {
    if (_busy) return;
    _busy = true;
    _errorCode = null;
    notifyListeners();

    final result = await _service.signInWithPassword(username, password);
    _busy = false;
    if (result.ok) {
      _user = result.user;
      // Deliberately not awaited: the permission prompt must not hold the user
      // on the login screen behind a spinner.
      unawaited(_afterSignIn());
    } else {
      _errorCode = switch (result.failure!) {
        SignInFailure.invalidCredentials => 'invalid_credentials',
        SignInFailure.notAllowed => 'not_allowed',
        SignInFailure.tooManyAttempts => 'too_many_attempts',
        SignInFailure.failed => 'sign_in_failed',
      };
    }
    notifyListeners();
  }

  /// Clears a stale error once the user starts correcting their input.
  void clearError() {
    if (_errorCode == null) return;
    _errorCode = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    // Drop the push token BEFORE tearing down the session: the Firestore rule
    // on device_tokens requires an authenticated caller, so deleting after
    // signOut would be rejected and leave the phone receiving alerts.
    await _push?.unregister();
    await _service.signOut();
    _user = null;
    _errorCode = null;
    notifyListeners();
  }

  /// Registers this device for push once a session exists. Never throws —
  /// `PushService` swallows its own failures, and a device that cannot
  /// register must still be able to use the app.
  Future<void> _afterSignIn() async {
    final push = _push;
    final email = _user?.email;
    if (push == null || email == null) return;
    await push.registerFor(email);
    push.listenForTokenRefresh();
  }
}
