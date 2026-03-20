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
  guest,
  host,
  both;

  String get label => switch (this) {
        AdminUserRole.guest  => 'Guest',
        AdminUserRole.host   => 'Host',
        AdminUserRole.both   => 'Both',
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
  });

  final String id;
  final String username;
  final String email;
  final String phone;
  final AdminUserRole role;
  final AdminUserStatus status;

  AdminUser copyWith({
    String? id,
    String? username,
    String? email,
    String? phone,
    AdminUserRole? role,
    AdminUserStatus? status,
  }) {
    return AdminUser(
      id:       id       ?? this.id,
      username: username ?? this.username,
      email:    email    ?? this.email,
      phone:    phone    ?? this.phone,
      role:     role     ?? this.role,
      status:   status   ?? this.status,
    );
  }
}
