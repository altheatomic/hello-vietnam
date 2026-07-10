import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/admin/domain/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserPageResult {
  const AdminUserPageResult({required this.users, required this.totalCount});

  final List<AdminUser> users;
  final int totalCount;
}

class AdminUserRepository {
  AdminUserRepository({
    SupabaseClient? client,
    SupabaseTableClient? tableClient,
  }) : _clientOverride = client,
       _tableClient = tableClient;

  final SupabaseClient? _clientOverride;
  final SupabaseTableClient? _tableClient;
  bool? _supportsStatusColumn;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  Future<AdminUserPageResult> fetchUsers({
    required int page,
    required int pageSize,
    String query = '',
    AdminUserStatus? status,
    String? sortField,
    String? sortDirection,
  }) async {
    final List<Map<String, dynamic>> accountRows = await _fetchAccountRows(
      page: page,
      pageSize: pageSize,
      query: query,
      status: status,
      sortField: sortField,
      sortDirection: sortDirection,
    );
    final List<Map<String, dynamic>> contactRows = await _fetchContactRowsFor(
      accountRows
          .map((Map<String, dynamic> row) => row['id_user']?.toString())
          .whereType<String>()
          .where((String id) => id.isNotEmpty)
          .toList(growable: false),
    );
    final Map<String, Map<String, dynamic>> contactsByUserId =
        <String, Map<String, dynamic>>{
          for (final Map<String, dynamic> row in contactRows)
            row['id_user']?.toString() ?? '': row,
        };

    final users = accountRows
        .map(
          (Map<String, dynamic> row) => _userFromRows(
            row,
            contactsByUserId[row['id_user']?.toString() ?? ''],
          ),
        )
        .toList(growable: false);

    return AdminUserPageResult(
      users: users,
      totalCount: _lastFetchTotalCount ?? users.length,
    );
  }

  int? _lastFetchTotalCount;

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

  Future<List<Map<String, dynamic>>> _fetchAccountRows({
    required int page,
    required int pageSize,
    required String query,
    required AdminUserStatus? status,
    required String? sortField,
    required String? sortDirection,
  }) async {
    final bool supportsStatus = await _hasStatusColumn();
    final range = SupabaseTableClient.rangeForPage(
      page: page,
      pageSize: pageSize,
    );
    dynamic filter = _client
        .from('user_account')
        .select(
          supportsStatus
              ? 'id_user, full_name, username, role, status'
              : 'id_user, full_name, username, role',
        );

    if (supportsStatus && status != null) {
      filter = filter.eq('status', status.name);
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = _escapeSearch(trimmedQuery);
      filter = filter.or(
        'id_user.ilike.%$escaped%,full_name.ilike.%$escaped%,username.ilike.%$escaped%',
      );
    }

    final String sortColumn = switch (sortField) {
      'fullName' => 'full_name',
      _ => 'created_at',
    };
    final bool ascending = sortDirection == 'ascending';
    final SupabasePagedRows pageRows = await _resolvedTableClient.pagedRows(
      'user_account page',
      () async {
        return filter
            .order(sortColumn, ascending: ascending)
            .range(range.from, range.to)
            .count(CountOption.exact);
      },
    );
    _lastFetchTotalCount = pageRows.totalCount;
    return pageRows.rows;
  }

  Future<List<Map<String, dynamic>>> _fetchContactRowsFor(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const <Map<String, dynamic>>[];
    return _resolvedTableClient.list(
      'user_contact lookup',
      () async {
        return _client
            .from('user_contact')
            .select('id_user, email, phone_number')
            .inFilter('id_user', userIds)
            .limit(userIds.length);
      },
    );
  }

  Future<bool> _hasStatusColumn() async {
    if (_supportsStatusColumn != null) {
      return _supportsStatusColumn!;
    }

    try {
      await _resolvedTableClient.list(
        'user status column',
        () async => _client.from('user_account').select('status').limit(1),
      );
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

  AdminUser _userFromRows(
    Map<String, dynamic> row,
    Map<String, dynamic>? contact,
  ) {
    final String id = row['id_user']?.toString() ?? '';
    final String? username = (row['username'] as String?)?.trim();
    final String? email = (contact?['email'] as String?)?.trim();
    return AdminUser(
      id: id,
      fullName: (row['full_name'] as String?)?.trim(),
      username: username?.isNotEmpty == true ? username! : (email ?? id),
      email: email ?? '',
      phone: (contact?['phone_number'] as String?)?.trim() ?? '',
      role: _parseRole(row['role'] as String?),
      status: _parseStatus(row['status'] as String?),
    );
  }

  String _escapeSearch(String query) {
    return query.replaceAll('%', r'\%').replaceAll(',', r'\,');
  }
}
