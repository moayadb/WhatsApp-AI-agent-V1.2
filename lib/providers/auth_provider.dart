import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Where the login screen currently is in the magic-link flow.
enum LoginPhase {
  /// Asking for an email address.
  enterEmail,

  /// Link sent — waiting for the user to open it from their inbox.
  linkSent,

  /// A valid sign-in link was opened, but this browser has no saved email
  /// (link came from another device/profile). Ask for it, then finish.
  confirmEmail,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

  // -------------------------------------------------------------------
  // TESTER BYPASS — typing this code into the email field signs in as a
  // local owner-level user with NO Firebase round-trip. For the closed
  // testing group only; REMOVE before any real release (delete this block,
  // the check in requestMagicLink, and the restore/signOut handling).
  //
  // Change the code per build without touching source:
  //   flutter build apk --release --dart-define=BYPASS_CODE=your-secret
  // -------------------------------------------------------------------
  static const String bypassCode =
      String.fromEnvironment('BYPASS_CODE', defaultValue: 'sanayed2026');
  static const String _bypassPrefsKey = 'bypass_session';

  static const AppUser _bypassUser = AppUser(
    username: 'tester',
    displayName: 'Tester',
    role: UserRole.owner,
  );

  AppUser? _user;
  bool _restoring = true;
  LoginPhase _phase = LoginPhase.enterEmail;
  String _email = '';
  bool _busy = false;
  String? _errorCode;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get restoring => _restoring;
  LoginPhase get phase => _phase;
  String get email => _email;
  bool get busy => _busy;

  /// One of: null | 'not_allowed' | 'send_failed' | 'link_failed' |
  /// 'google_failed'.
  String? get errorCode => _errorCode;
  String? get errorDetail => _service.lastError;

  /// Restores an existing session, and completes sign-in if the app was
  /// opened via a magic link. [initialLink] is the URL the app launched with
  /// (on web that is the current page URL).
  Future<void> restore({String? initialLink}) async {
    // A bypass session survives restarts until sign-out.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_bypassPrefsKey) ?? false) {
      _user = _bypassUser;
      _restoring = false;
      notifyListeners();
      return;
    }
    if (initialLink != null && initialLink.isNotEmpty) {
      final handled = await tryCompleteFromLink(initialLink, notify: false);
      if (handled) {
        _restoring = false;
        notifyListeners();
        return;
      }
    }
    // A link that needs the email confirmed must not be overwritten here.
    if (_phase != LoginPhase.confirmEmail) {
      _user = await _service.restoreSession();
      _email = await _service.pendingEmail() ?? '';
      if (_user == null && _email.isNotEmpty) _phase = LoginPhase.linkSent;
    }
    _restoring = false;
    notifyListeners();
  }

  /// The sign-in link currently being processed, held so the confirm-email
  /// step can retry against it.
  String? _pendingLink;

  /// Returns true if [link] was a sign-in link AND sign-in succeeded.
  Future<bool> tryCompleteFromLink(
    String link, {
    bool notify = true,
    String? emailOverride,
  }) async {
    if (!_service.isMagicLink(link)) return false;
    _pendingLink = link;
    _busy = true;
    _errorCode = null;
    if (notify) notifyListeners();

    final user = await _service.completeSignInFromLink(
      link,
      emailOverride: emailOverride,
    );
    _busy = false;
    if (user == null) {
      // Distinguish "we just don't know which email" from a genuinely bad
      // link — the first is recoverable by asking the user.
      if (_service.lastError == 'no-pending-email') {
        _phase = LoginPhase.confirmEmail;
        _errorCode = null;
      } else {
        _errorCode = 'link_failed';
        _phase = LoginPhase.enterEmail;
      }
      if (notify) notifyListeners();
      return false;
    }
    _user = user;
    _pendingLink = null;
    _phase = LoginPhase.enterEmail;
    if (notify) notifyListeners();
    return true;
  }

  /// Finishes a link opened in a browser that had no saved email.
  Future<void> confirmEmailAndSignIn(String email) async {
    final link = _pendingLink;
    if (link == null) return;
    _email = email.trim();
    await tryCompleteFromLink(link, emailOverride: _email);
  }

  /// Runs the allowlist check and sends the link. The tester bypass code is
  /// intercepted here, before anything touches Firebase.
  Future<void> requestMagicLink(String email) async {
    final input = email.trim();
    if (input == bypassCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bypassPrefsKey, true);
      _user = _bypassUser;
      _errorCode = null;
      _busy = false;
      notifyListeners();
      return;
    }

    _busy = true;
    _errorCode = null;
    _email = input;
    notifyListeners();

    final result = await _service.sendMagicLink(_email);
    _busy = false;
    switch (result) {
      case LinkRequestResult.sent:
        _phase = LoginPhase.linkSent;
      case LinkRequestResult.notAllowed:
        _errorCode = 'not_allowed';
      case LinkRequestResult.failed:
        _errorCode = 'send_failed';
    }
    notifyListeners();
  }

  Future<void> resend() => requestMagicLink(_email);

  /// Google sign-in — gated by the same allowlist inside the service.
  Future<void> signInWithGoogle() async {
    _busy = true;
    _errorCode = null;
    notifyListeners();

    final user = await _service.signInWithGoogle();
    _busy = false;
    if (user == null) {
      _errorCode =
          _service.lastError == 'not-allowed' ? 'not_allowed' : 'google_failed';
    } else {
      _user = user;
      _phase = LoginPhase.enterEmail;
    }
    notifyListeners();
  }

  /// Back to the email field (e.g. wrong address typed).
  void editEmail() {
    _phase = LoginPhase.enterEmail;
    _errorCode = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bypassPrefsKey);
    await _service.signOut();
    _user = null;
    _phase = LoginPhase.enterEmail;
    _email = '';
    _errorCode = null;
    notifyListeners();
  }
}
