/// Status of a registered user, used across the admin UI.
enum AdminUserStatus {
  active,
  banned;

  String get label => switch (this) {
    AdminUserStatus.active => 'Active',
    AdminUserStatus.banned => 'Banned',
  };
}

/// Platform role for a registered user.
enum AdminUserRole {
  admin,
  user;

  String get label => switch (this) {
    AdminUserRole.admin => 'Admin',
    AdminUserRole.user => 'User',
  };
}

/// Lightweight domain model for the admin user management table.
///
/// All fields are immutable. Use [copyWith] to produce modified copies
/// (e.g., when toggling ban status in page state).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.fullName,
  });

  final String id;

  /// Display name — populated when a user is created via the admin form.
  /// Existing mock records leave this null; the export falls back to [username].
  final String? fullName;
  final String username;
  final String email;
  final String phone;
  final AdminUserRole role;
  final AdminUserStatus status;

  AdminUser copyWith({
    String? id,
    String? fullName,
    String? username,
    String? email,
    String? phone,
    AdminUserRole? role,
    AdminUserStatus? status,
  }) {
    return AdminUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }
}
