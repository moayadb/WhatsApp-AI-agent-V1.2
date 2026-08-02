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

/// The signed-in user, projected from a Firebase Auth account plus its
/// `allowed_users` row. Framework-free on purpose so it stays unit-testable.
class AppUser {
  const AppUser({
    required this.username,
    required this.email,
    required this.displayName,
    required this.role,
  });

  /// What the user types at sign-in — the local part only, no domain.
  final String username;

  /// The Firebase Auth address, `<username>@sanayed.app`. Used to match the
  /// `allowed_users` row and to stamp the device's push token; **never shown
  /// in the UI**, because staff are not meant to know the domain exists.
  final String email;

  final String displayName;
  final UserRole role;
}
