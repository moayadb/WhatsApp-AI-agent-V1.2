import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../services/analyzer_api.dart';
import '../services/push_service.dart';
import '../services/realtime_service.dart';

/// Where the app should send the user once they are signed in.
enum SessionStage {
  /// Deciding — a stored token is being checked.
  restoring,

  signedOut,

  /// Journey step 2 has not finished.
  intake,

  /// Signed in with the intake done. Step 3 is reachable but not forced:
  /// a manager with no numbers linked yet still gets a working app.
  ready,
}

/// Session state for the whole app.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required ApiClient client,
    required AnalyzerApi api,
    required RealtimeService realtime,
    required PushService push,
    required SharedPreferences prefs,
  })  : _client = client,
        _api = api,
        _realtime = realtime,
        _push = push,
        _prefs = prefs {
    // A token the server no longer accepts must not leave the user staring at
    // a screen that fails to load.
    _client.onUnauthorized = () {
      if (_stage != SessionStage.signedOut) signOut();
    };
  }

  static const _tokenKey = 'session_token';

  final ApiClient _client;
  final AnalyzerApi _api;
  final RealtimeService _realtime;
  final PushService _push;
  final SharedPreferences _prefs;

  SessionStage _stage = SessionStage.restoring;
  AppUser? _user;
  Org? _org;
  OrgSettings? _settings;
  String? _errorCode;
  bool _busy = false;

  SessionStage get stage => _stage;
  AppUser? get user => _user;
  Org? get org => _org;
  OrgSettings? get settings => _settings;
  String? get errorCode => _errorCode;
  bool get busy => _busy;
  bool get isSignedIn => _stage == SessionStage.intake || _stage == SessionStage.ready;

  /// Restore a stored session on launch.
  Future<void> restore() async {
    final token = _prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      _stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }

    _client.token = token;
    try {
      await _loadSession();
      _realtime.connect(token);
      // Not awaited: registration asks for a system permission and can sit on
      // a dialog for as long as the manager takes to read it. The launch
      // screen must not wait behind that.
      unawaited(_push.register());
    } on ApiException catch (error) {
      // Offline at launch should not log anybody out; only a rejected token
      // should.
      if (error.isNetwork) {
        _stage = SessionStage.signedOut;
      } else {
        await _prefs.remove(_tokenKey);
        _client.token = null;
        _stage = SessionStage.signedOut;
      }
    }
    notifyListeners();
  }

  /// [locale] is the language the app is showing at signup. It seeds
  /// `orgs.locale`, which the analysis workflow writes alerts in — so the first
  /// alert arrives in the right language without the manager having to visit
  /// Settings to set one.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String locale,
    String? companyName,
  }) =>
      _authenticate(
        () => _api.signUp(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
          locale: locale,
          companyName: companyName,
        ),
      );

  Future<bool> signIn(String email, String password) =>
      _authenticate(() => _api.signIn(email, password));

  Future<bool> _authenticate(Future<String> Function() request) async {
    _busy = true;
    _errorCode = null;
    notifyListeners();

    try {
      final token = await request();
      await _prefs.setString(_tokenKey, token);
      _client.token = token;
      await _loadSession();
      _realtime.connect(token);
      unawaited(_push.register());
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      _stage = SessionStage.signedOut;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadSession() async {
    final session = await _api.me();
    _user = session.user;
    _org = session.org;
    _settings = session.settings;
    _stage = session.org.onboardingCompleted
        ? SessionStage.ready
        : SessionStage.intake;
  }

  /// Called when the intake conversation finishes.
  void completeIntake(OrgSettings? settings) {
    if (settings != null) _settings = settings;
    _stage = SessionStage.ready;
    notifyListeners();
  }

  /// Pick up counts and settings changed elsewhere (numbers linked, thresholds
  /// edited) without a full sign-in.
  Future<void> refresh() async {
    if (!isSignedIn) return;
    try {
      final session = await _api.me();
      _user = session.user;
      _org = session.org;
      _settings = session.settings;
      notifyListeners();
    } on ApiException {
      // A failed refresh is not worth interrupting the user over.
    }
  }

  Future<void> signOut() async {
    // Before the token is cleared: the DELETE is authenticated, and a phone
    // that keeps its row keeps receiving this org's alerts after the next
    // person signs in on it.
    await _push.unregister();

    _realtime.disconnect();
    await _prefs.remove(_tokenKey);
    _client.token = null;
    _user = null;
    _org = null;
    _settings = null;
    _errorCode = null;
    _stage = SessionStage.signedOut;
    notifyListeners();
  }
}
