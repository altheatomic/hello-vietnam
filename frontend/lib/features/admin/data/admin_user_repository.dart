import 'package:hellovietnam/features/admin/domain/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserRepository {
  AdminUserRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  bool? _supportsStatusColumn;

  Future<List<AdminUser>> fetchUsers() async {
    final List<Map<String, dynamic>> accountRows = await _fetchAccountRows();
    final List<Map<String, dynamic>> contactRows = await _fetchContactRows();

    final Map<String, Map<String, dynamic>> contactsByUserId =
        <String, Map<String, dynamic>>{
          for (final Map<String, dynamic> row in contactRows)
            (row['id_user'] as String): row,
        };

    return accountRows.map((Map<String, dynamic> row) {
      final String id = (row['id_user'] as String?) ?? '';
      final Map<String, dynamic>? contact = contactsByUserId[id];

      return AdminUser(
        id: id,
        fullName: (row['full_name'] as String?)?.trim(),
        username:
            (row['username'] as String?)?.trim().isNotEmpty == true
                ? (row['username'] as String).trim()
                : ((contact?['email'] as String?)?.trim() ?? id),
        email: (contact?['email'] as String?)?.trim() ?? '',
        phone: (contact?['phone_number'] as String?)?.trim() ?? '',
        role: _parseRole(row['role'] as String?),
        status: _parseStatus(row['status'] as String?),
      );
    }).toList();
  }

  Future<AdminUser> createUser({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required AdminUserRole role,
  }) async {
    final Map<String, dynamic> insertPayload = <String, dynamic>{
      'full_name': fullName,
      'username': username,
      'role': role.name,
    };

    if (await _hasStatusColumn()) {
      insertPayload['status'] = AdminUserStatus.active.name;
    }

    final Map<String, dynamic> createdAccount =
        await _client
            .from('user_account')
            .insert(insertPayload)
            .select('id_user, full_name, username, role')
            .single();

    final String userId = createdAccount['id_user'] as String;

    await _client.from('user_contact').upsert(<String, dynamic>{
      'id_user': userId,
      'email': email,
      'phone_number': phone,
    });

    return AdminUser(
      id: userId,
      fullName: (createdAccount['full_name'] as String?)?.trim(),
      username: (createdAccount['username'] as String?)?.trim() ?? username,
      email: email,
      phone: phone,
      role: _parseRole(createdAccount['role'] as String?),
      status: AdminUserStatus.active,
    );
  }

  Future<AdminUserStatus> toggleStatus(AdminUser user) async {
    if (!await _hasStatusColumn()) {
      throw Exception(
        'Bang user_account chua co cot status. Hay them cot status truoc khi dung ban/unban.',
      );
    }

    final AdminUserStatus nextStatus =
        user.status == AdminUserStatus.active
            ? AdminUserStatus.banned
            : AdminUserStatus.active;

    await _client
        .from('user_account')
        .update(<String, dynamic>{'status': nextStatus.name})
        .eq('id_user', user.id);

    return nextStatus;
  }

  Future<List<Map<String, dynamic>>> _fetchAccountRows() async {
    if (await _hasStatusColumn()) {
      final List<dynamic> rows = await _client
          .from('user_account')
          .select('id_user, full_name, username, role, status')
          .order('created_at', ascending: false);
      return rows.cast<Map<String, dynamic>>();
    }

    final List<dynamic> rows = await _client
        .from('user_account')
        .select('id_user, full_name, username, role')
        .order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchContactRows() async {
    final List<dynamic> rows = await _client
        .from('user_contact')
        .select('id_user, email, phone_number');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<bool> _hasStatusColumn() async {
    if (_supportsStatusColumn != null) {
      return _supportsStatusColumn!;
    }

    try {
      await _client.from('user_account').select('status').limit(1);
      _supportsStatusColumn = true;
    } catch (_) {
      _supportsStatusColumn = false;
    }

    return _supportsStatusColumn!;
  }

  AdminUserRole _parseRole(String? rawRole) {
    switch ((rawRole ?? '').trim().toLowerCase()) {
      case 'admin':
        return AdminUserRole.admin;
      default:
        return AdminUserRole.user;
    }
  }

  AdminUserStatus _parseStatus(String? rawStatus) {
    switch ((rawStatus ?? '').trim().toLowerCase()) {
      case 'banned':
        return AdminUserStatus.banned;
      default:
        return AdminUserStatus.active;
    }
  }
}
