import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Why a sign-in attempt did not produce a session.
enum SignInFailure {
  /// Username or password did not match. Deliberately does not distinguish
  /// "no such account" from "wrong password" — see [_mapAuthError].
  invalidCredentials,

  /// Firebase authenticated the account, but it is not in `allowed_users`.
  notAllowed,

  /// Firebase temporarily blocked the account after repeated failures.
  tooManyAttempts,

  /// Network trouble, provider disabled, allowlist unreachable, anything else.
  failed,
}

/// Outcome of a sign-in attempt: either a user, or a reason there isn't one.
class SignInResult {
  const SignInResult.success(AppUser this.user) : failure = null;
  const SignInResult.failure(SignInFailure this.failure) : user = null;

  final AppUser? user;
  final SignInFailure? failure;

  bool get ok => user != null;
}

/// Auth abstraction. The rest of the app depends only on this interface, so
/// the sign-in mechanism can change without touching the UI.
abstract class AuthService {
  /// Signs in with a username and password.
  ///
  /// The username is a presentation convenience only: internally every account
  /// is an ordinary Firebase Auth email/password user. Credentials are checked
  /// by Firebase and nowhere else — this app holds no usernames, no passwords
  /// and performs no local comparison.
  Future<SignInResult> signInWithPassword(String username, String password);

  Future<void> signOut();

  /// Restores an existing Firebase session on startup.
  Future<AppUser?> restoreSession();

  /// Last failure message, for diagnostics.
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

  static const allowlistCollection = 'allowed_users';

  /// Every account is a Firebase email/password user under this domain. Staff
  /// type the local part only; the domain is never shown and never typed.
  ///
  /// It is synthetic — no mailbox exists behind it. That is why this app has
  /// no signup, no password reset and no email verification: none of those
  /// could deliver anywhere. Accounts are created by hand in the Firebase
  /// Console, and a forgotten password is reset there too.
  static const String accountDomain = 'sanayed.app';

  String? _lastError;

  @override
  String? get lastError => _lastError;

  /// Maps a typed username onto its Firebase Auth address.
  ///
  /// Strips the domain first so that a user who types the full address anyway
  /// — or whose password manager autofills it — does not end up attempting
  /// `name@sanayed.app@sanayed.app`.
  static String emailForUsername(String username) {
    const suffix = '@$accountDomain';
    var name = username.trim().toLowerCase();
    if (name.endsWith(suffix)) {
      name = name.substring(0, name.length - suffix.length);
    }
    return '$name$suffix';
  }

  /// Gatekeeper: the account's address must exist in `allowed_users`.
  ///
  /// Firestore string equality is case-sensitive. [email] always arrives
  /// lowercased from [emailForUsername], so allowlist rows must store the
  /// address lowercased too.
  Future<bool> _isAllowed(String email) async {
    final snap = await _db
        .collection(allowlistCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<SignInResult> signInWithPassword(
    String username,
    String password,
  ) async {
    _lastError = null;
    final email = emailForUsername(username);
    // An empty username collapses to a bare "@sanayed.app"; reject it here
    // rather than spending a round-trip on a request that cannot succeed.
    if (email.startsWith('@') || password.isEmpty) {
      return const SignInResult.failure(SignInFailure.invalidCredentials);
    }

    final UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _lastError = e.message ?? e.code;
      return SignInResult.failure(_mapAuthError(e.code));
    } catch (e) {
      _lastError = '$e';
      return const SignInResult.failure(SignInFailure.failed);
    }

    // The same gatekeeper Google sign-in uses. Firebase has already minted a
    // session by this point, so a non-allowlisted account is signed straight
    // back out before it can read anything.
    try {
      if (!await _isAllowed(email)) {
        await _auth.signOut();
        _lastError = 'not-allowed';
        return const SignInResult.failure(SignInFailure.notAllowed);
      }
    } catch (e) {
      // Failing open here would leave an unvetted account holding a live
      // session, so an unreachable allowlist signs out too.
      await _auth.signOut();
      _lastError = 'Allowlist lookup failed: $e';
      return const SignInResult.failure(SignInFailure.failed);
    }

    final user = await _toAppUser(cred.user);
    if (user == null) {
      await _auth.signOut();
      _lastError = 'no-user';
      return const SignInResult.failure(SignInFailure.failed);
    }
    return SignInResult.success(user);
  }

  /// Newer Firebase SDKs collapse unknown-account and wrong-password into a
  /// single `invalid-credential`; older ones still send the split codes. Every
  /// one of them must look identical to the user, so a wrong guess cannot be
  /// used to discover which usernames exist.
  SignInFailure _mapAuthError(String code) => switch (code) {
        'invalid-credential' ||
        'invalid-login-credentials' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' =>
          SignInFailure.invalidCredentials,
        'too-many-requests' => SignInFailure.tooManyAttempts,
        // A disabled account is a revoked account: report it as such rather
        // than telling the user to retype a password that is in fact correct.
        'user-disabled' => SignInFailure.notAllowed,
        _ => SignInFailure.failed,
      };

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<AppUser?> restoreSession() => _toAppUser(_auth.currentUser);

  /// Maps a Firebase user onto the app's user model. The role comes from the
  /// allowlist row when present, so an admin can grant sales/purchasing/owner
  /// by editing Firestore; it falls back to `owner` rather than locking
  /// someone out of their own data.
  Future<AppUser?> _toAppUser(User? user) async {
    if (user == null) return null;
    final email = (user.email ?? '').toLowerCase();
    final username = email.split('@').first;
    return AppUser(
      username: username,
      email: email,
      displayName: _displayNameFor(user, username),
      role: await roleFor(email),
    );
  }

  /// Staff never see the synthetic domain, so the fallback display name is
  /// built from the username alone.
  String _displayNameFor(User user, String username) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username.isEmpty) return '';
    return username[0].toUpperCase() + username.substring(1);
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
