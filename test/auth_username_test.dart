import 'package:flutter_test/flutter_test.dart';
import 'package:tulip_alerts/services/auth_service.dart';

/// The username → Firebase address mapping is the whole contract behind the
/// login form: staff type a bare username, Firebase only ever sees an email.
/// These are pure-function tests — no Firebase instance is created.
void main() {
  group('emailForUsername', () {
    test('appends the account domain to a bare username', () {
      expect(
        FirebaseAuthService.emailForUsername('waseem'),
        'waseem@sanayed.app',
      );
    });

    test('trims and lowercases', () {
      expect(
        FirebaseAuthService.emailForUsername('  Waseem  '),
        'waseem@sanayed.app',
      );
    });

    test('does not double the domain when the full address is typed', () {
      expect(
        FirebaseAuthService.emailForUsername('waseem@sanayed.app'),
        'waseem@sanayed.app',
      );
      expect(
        FirebaseAuthService.emailForUsername('Waseem@Sanayed.App'),
        'waseem@sanayed.app',
      );
    });

    test('leaves a foreign domain alone rather than guessing', () {
      // Not a valid account, but it must reach Firebase as typed so the
      // failure is "wrong credentials" and not a silently rewritten address.
      expect(
        FirebaseAuthService.emailForUsername('waseem@gmail.com'),
        'waseem@gmail.com@sanayed.app',
      );
    });

    test('an empty username collapses to a bare domain', () {
      // The service rejects this before calling Firebase.
      expect(FirebaseAuthService.emailForUsername('   '), '@sanayed.app');
    });
  });
}
