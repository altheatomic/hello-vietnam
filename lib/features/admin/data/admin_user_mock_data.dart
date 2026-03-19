import '../domain/admin_user.dart';

/// Mock user records for the admin user management table.
///
/// Covers a representative spread of roles and statuses so the table
/// renders both badge variants and both action states during development.
final List<AdminUser> mockAdminUsers = [
  const AdminUser(
    id: '111111',
    username: 'BalajiNant',
    email: 'aaaa@gmail.com',
    phone: '091122334',
    role: AdminUserRole.guest,
    status: AdminUserStatus.active,
  ),
  const AdminUser(
    id: '222222',
    username: 'NithyaMenon',
    email: 'bbb@gmail.com',
    phone: '022334444',
    role: AdminUserRole.host,
    status: AdminUserStatus.banned,
  ),
  const AdminUser(
    id: '111223',
    username: 'MeeraGonzalez',
    email: 'ccc@gmail.com',
    phone: '093378445',
    role: AdminUserRole.both,
    status: AdminUserStatus.active,
  ),
  const AdminUser(
    id: '112223',
    username: 'KarthikSubramanian',
    email: 'ddd@gmail.com',
    phone: '093745566',
    role: AdminUserRole.host,
    status: AdminUserStatus.banned,
  ),
  const AdminUser(
    id: '113001',
    username: 'AmiraHassan',
    email: 'amira.h@gmail.com',
    phone: '098123456',
    role: AdminUserRole.guest,
    status: AdminUserStatus.active,
  ),
  const AdminUser(
    id: '113002',
    username: 'RudraPratap',
    email: 'rudra.p@gmail.com',
    phone: '091234567',
    role: AdminUserRole.both,
    status: AdminUserStatus.active,
  ),
  const AdminUser(
    id: '113003',
    username: 'JoleneOrr',
    email: 'jolene.o@gmail.com',
    phone: '094567890',
    role: AdminUserRole.host,
    status: AdminUserStatus.active,
  ),
  const AdminUser(
    id: '113004',
    username: 'AryanRoy',
    email: 'aryan.r@gmail.com',
    phone: '097654321',
    role: AdminUserRole.guest,
    status: AdminUserStatus.banned,
  ),
];
