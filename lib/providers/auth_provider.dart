import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

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
    await _service.signOut();
    _user = null;
    _errorCode = null;
    notifyListeners();
  }
}
