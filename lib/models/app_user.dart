import 'alert.dart';

enum UserRole {
  owner,
  sales,
  purchasing;

  /// The department this role's alert filter defaults to.
  /// `null` means "all departments" (owner).
  ///
  /// The new department vocabulary has no `purchasing` — `operations` is the
  /// closest match for the demo purchasing-manager role.
  Department? get defaultDepartment => switch (this) {
        owner => null,
        sales => Department.sales,
        purchasing => Department.operations,
      };
}

/// A demo user. Deliberately trivial per spec §4 — no Firebase Auth.
class AppUser {
  const AppUser({
    required this.username,
    required this.displayName,
    required this.role,
  });

  final String username;
  final String displayName;
  final UserRole role;
}
