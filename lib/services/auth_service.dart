import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Outcome of asking for a magic link.
enum LinkRequestResult {
  sent,

  /// The email is not in the `allowed_users` allowlist.
  notAllowed,

  /// Firebase rejected the request (provider disabled, bad domain, offline…).
  failed,
}

/// Auth abstraction. The rest of the app depends only on this interface, so
/// the sign-in mechanism can change without touching the UI.
abstract class AuthService {
  /// Checks the allowlist, then emails a sign-in link.
  Future<LinkRequestResult> sendMagicLink(String email);

  /// True when [link] is a Firebase email sign-in link.
  bool isMagicLink(String link);

  /// Completes sign-in from a link. [emailOverride] is used when the link was
  /// opened in a different browser/device than it was requested from, so the
  /// saved address is unavailable and the user re-types it.
  Future<AppUser?> completeSignInFromLink(String link, {String? emailOverride});

  /// The email a link was last requested for, if any.
  Future<String?> pendingEmail();

  /// Google sign-in, gated by the same `allowed_users` allowlist as magic
  /// links — Google must not be a side door around the gatekeeper.
  Future<AppUser?> signInWithGoogle();

  Future<void> signOut();

  /// Restores an existing Firebase session on startup.
  Future<AppUser?> restoreSession();

  /// Last failure message, for surfacing in the UI.
  String? get lastError;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _emailKey = 'pending_sign_in_email';
  static const allowlistCollection = 'allowed_users';

  String? _lastError;

  @override
  String? get lastError => _lastError;

  // ---------------------------------------------------------------------
  // TODO(you): confirm these before magic links will work.
  //
  //  * url — MUST be an https URL on a domain listed under Firebase Console
  //    → Authentication → Settings → Authorized domains. Your Hosting domain
  //    (https://whatsapp-ai-agent-waseem.web.app) is authorized by default.
  //    For local web testing point it at http://localhost:5599 and add
  //    `localhost` to that same authorized-domains list.
  //
  //    NOTE: Firebase Dynamic Links has been shut down, so there is no
  //    dynamicLinkDomain here any more — a plain https continue URL is the
  //    current supported approach.
  //
  //  * iOSBundleId — your iOS bundle id (no iOS target exists yet).
  //  * androidPackageName — com.sanayed.analyzer, matching
  //    android/app/build.gradle.kts. Opening the link straight into the
  //    installed Android app additionally needs an App Links intent-filter
  //    plus a hosted /.well-known/assetlinks.json; until that exists the link
  //    opens in the browser, which still completes sign-in on web.
  // ---------------------------------------------------------------------
  /// Where the emailed link sends the user back to.
  ///
  /// Defaults to the local dev server so sign-in can be tested immediately —
  /// Firebase authorizes `localhost` out of the box (any port). Override per
  /// environment without touching code:
  ///   flutter build web --dart-define=AUTH_CONTINUE_URL=https://your.domain/
  static const String continueUrl = String.fromEnvironment(
    'AUTH_CONTINUE_URL',
    defaultValue: 'http://localhost:5599/',
  );

  // NOTE: no iOSBundleId here — no iOS app is registered in this Firebase
  // project, and passing an unregistered bundle id makes Firebase reject the
  // whole sendSignInLinkToEmail call (the "could not send" failure seen on
  // the first Android build).
  static final ActionCodeSettings _actionCodeSettings = ActionCodeSettings(
    url: continueUrl,
    handleCodeInApp: true, // required for email-link sign-in
    androidPackageName: 'com.sanayed.analyzer',
    androidInstallApp: false,
  );

  /// Gatekeeper: the email must exist in `allowed_users`.
  ///
  /// Firestore string equality is case-sensitive, so the lookup uses a
  /// normalised lowercase address. Documents are expected to store `email`
  /// already lowercased; a second exact-case query covers legacy rows that
  /// were entered with capitals.
  Future<bool> _isAllowed(String normalisedEmail, String rawEmail) async {
    Future<bool> matches(String value) async {
      final snap = await _db
          .collection(allowlistCollection)
          .where('email', isEqualTo: value)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    }

    if (await matches(normalisedEmail)) return true;
    if (rawEmail != normalisedEmail && await matches(rawEmail)) return true;
    return false;
  }

  @override
  Future<LinkRequestResult> sendMagicLink(String email) async {
    _lastError = null;
    final raw = email.trim();
    final normalised = raw.toLowerCase();
    if (normalised.isEmpty) return LinkRequestResult.failed;

    try {
      if (!await _isAllowed(normalised, raw)) {
        return LinkRequestResult.notAllowed;
      }
    } catch (e) {
      _lastError = 'Allowlist lookup failed: $e';
      return LinkRequestResult.failed;
    }

    try {
      await _auth.sendSignInLinkToEmail(
        email: normalised,
        actionCodeSettings: _actionCodeSettings,
      );
      // Firebase requires the same address back when completing the link.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailKey, normalised);
      return LinkRequestResult.sent;
    } on FirebaseAuthException catch (e) {
      _lastError = e.message ?? e.code;
      return LinkRequestResult.failed;
    } catch (e) {
      _lastError = '$e';
      return LinkRequestResult.failed;
    }
  }

  @override
  bool isMagicLink(String link) {
    try {
      return _auth.isSignInWithEmailLink(link);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> pendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  @override
  Future<AppUser?> completeSignInFromLink(String link, {String? emailOverride}) async {
    _lastError = null;
    final email = emailOverride?.trim().toLowerCase() ?? await pendingEmail();
    if (email == null || email.isEmpty) {
      // Link opened on a different device/browser than it was requested from.
      // The caller re-prompts for the address and calls back with an override.
      _lastError = 'no-pending-email';
      return null;
    }
    try {
      final cred = await _auth.signInWithEmailLink(email: email, emailLink: link);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emailKey);
      return await _toAppUser(cred.user);
    } on FirebaseAuthException catch (e) {
      _lastError = e.message ?? e.code;
      return null;
    }
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    _lastError = null;
    try {
      final provider = GoogleAuthProvider();
      // Web: popup. Android/iOS: the SDK's browser-based provider flow
      // (Custom Tab) — deliberately NOT the google_sign_in native plugin,
      // because the browser flow needs no SHA fingerprint registration and
      // no serverClientId, so it works on a fresh release APK as-is.
      final cred = kIsWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);

      final email = (cred.user?.email ?? '').toLowerCase();
      if (email.isEmpty || !await _isAllowed(email, email)) {
        // Same gatekeeper as magic links. The Firebase user was already
        // minted by Google, so sign straight back out before reporting.
        await _auth.signOut();
        _lastError = 'not-allowed';
        return null;
      }
      return await _toAppUser(cred.user);
    } on FirebaseAuthException catch (e) {
      // User closing the popup/tab lands here too — harmless codes like
      // popup-closed-by-user / web-context-canceled.
      _lastError = e.message ?? e.code;
      return null;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
  }

  @override
  Future<AppUser?> restoreSession() => _toAppUser(_auth.currentUser);

  /// Maps a Firebase user onto the app's user model. The role comes from the
  /// allowlist row when present, so an admin can grant sales/purchasing/owner
  /// by editing Firestore; it falls back to `owner` rather than locking
  /// someone out of their own data.
  Future<AppUser?> _toAppUser(User? user) async {
    if (user == null) return null;
    final email = (user.email ?? '').toLowerCase();
    return AppUser(
      username: email,
      displayName: _displayNameFor(user, email),
      role: await roleFor(email),
    );
  }

  String _displayNameFor(User user, String email) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  /// Role recorded on the allowlist row, defaulting to owner.
  Future<UserRole> roleFor(String email) async {
    try {
      final snap = await _db
          .collection(allowlistCollection)
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return UserRole.owner;
      final raw = (snap.docs.first.data()['role'] as String?)?.toLowerCase();
      return switch (raw) {
        'sales' => UserRole.sales,
        'purchasing' => UserRole.purchasing,
        _ => UserRole.owner,
      };
    } catch (_) {
      return UserRole.owner;
    }
  }
}
