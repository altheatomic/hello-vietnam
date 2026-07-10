import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/admin/data/admin_user_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('fetchUsers loads only the requested page and its contacts', () async {
    final _FakeTableClient tableClient = _FakeTableClient(
      responses: <String, Object?>{
        'user status column': <Map<String, dynamic>>[
          <String, dynamic>{'status': 'active'},
        ],
        'user_account page': _FakePostgrestPage(
          data: <Map<String, dynamic>>[
            <String, dynamic>{
              'id_user': 'user-1',
              'full_name': 'Nguyen An',
              'username': 'an',
              'role': 'admin',
              'status': 'active',
            },
          ],
          count: 27,
        ),
        'user_contact lookup': <Map<String, dynamic>>[
          <String, dynamic>{
            'id_user': 'user-1',
            'email': 'an@example.com',
            'phone_number': '0901',
          },
        ],
      },
    );
    final AdminUserRepository repository = AdminUserRepository(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      tableClient: tableClient,
    );

    final AdminUserPageResult result = await repository.fetchUsers(
      page: 2,
      pageSize: 10,
      query: 'an',
      status: AdminUserStatus.active,
      sortField: 'fullName',
      sortDirection: 'ascending',
    );

    expect(tableClient.runLabels, <String>[
      'user status column',
      'user_account page',
      'user_contact lookup',
    ]);
    expect(result.totalCount, 27);
    expect(result.users.single.id, 'user-1');
    expect(result.users.single.fullName, 'Nguyen An');
    expect(result.users.single.email, 'an@example.com');
    expect(result.users.single.phone, '0901');
    expect(result.users.single.role, AdminUserRole.admin);
    expect(result.users.single.status, AdminUserStatus.active);
  });
}

class _FakePostgrestPage {
  const _FakePostgrestPage({required this.data, required this.count});

  final List<Map<String, dynamic>> data;
  final int count;
}

class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({required this.responses});

  final Map<String, Object?> responses;
  final List<String> runLabels = <String>[];

  @override
  Future<T> run<T>(
    String label,
    Future<T> Function() request, {
    Duration? timeout,
  }) async {
    runLabels.add(label);
    if (!responses.containsKey(label)) {
      throw StateError('No fake response for $label.');
    }
    return responses[label] as T;
  }
}
