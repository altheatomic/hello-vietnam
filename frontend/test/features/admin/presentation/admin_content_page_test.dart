import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/admin/data/admin_content_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_content.dart';
import 'package:hellovietnam/features/admin/presentation/admin_shell.dart';
import 'package:hellovietnam/features/admin/presentation/pages/admin_content_page.dart';

void main() {
  testWidgets('loaded activity page fits the browser at 125 percent scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 912.5);
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AdminShell(
          currentPath: '/admin/activities',
          child: AdminContentPage(
            config: AdminContentConfigs.activity,
            repository: _EightRecordAdminContentRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('loading province layout fits a narrow admin viewport', (
    tester,
  ) async {
    final repository = _PendingAdminContentRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 900,
            child: SingleChildScrollView(
              child: AdminContentPage(
                config: AdminContentConfigs.province,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    repository.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit loads full admin content record before opening form', (
    tester,
  ) async {
    final _FakeAdminContentRepository repository =
        _FakeAdminContentRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 900,
            child: SingleChildScrollView(
              child: AdminContentPage(
                config: AdminContentConfigs.place,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit').first);
    await tester.pumpAndSettle();

    expect(repository.fetchRecordCount, 1);
    expect(find.text('Full admin detail'), findsOneWidget);
  });

  testWidgets('ignores stale search responses that finish out of order', (
    tester,
  ) async {
    final _ControlledSearchRepository repository =
        _ControlledSearchRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 900,
            child: SingleChildScrollView(
              child: AdminContentPage(
                config: AdminContentConfigs.place,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ha');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.pendingQueries, contains('ha'));

    await tester.enterText(find.byType(TextField), 'hue');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.pendingQueries, contains('hue'));

    repository.completeQuery('hue', name: 'Hue Citadel');
    await tester.pump();
    await tester.pump();
    expect(find.text('Hue Citadel'), findsOneWidget);

    repository.completeQuery('ha', name: 'Ha Long Bay');
    await tester.pump();
    await tester.pump();
    expect(find.text('Hue Citadel'), findsOneWidget);
    expect(find.text('Ha Long Bay'), findsNothing);
  });
}

class _EightRecordAdminContentRepository extends AdminContentRepository {
  @override
  Future<AdminPagedResult<AdminContentRecord>> fetchPage(
    AdminContentResourceConfig config, {
    required int page,
    required int pageSize,
    String query = '',
  }) async {
    return AdminPagedResult<AdminContentRecord>(
      items: List<AdminContentRecord>.generate(
        8,
        (index) => AdminContentRecord(
          id: 'activity-$index',
          idColumn: 'id_activity',
          values: <String, dynamic>{
            'id_activity': 'activity-$index',
            'name': 'Activity number $index',
            'short_description':
                'A representative activity description for overflow testing.',
            'status': 'active',
          },
        ),
      ),
      totalCount: 8,
    );
  }
}

class _PendingAdminContentRepository extends AdminContentRepository {
  final Completer<AdminPagedResult<AdminContentRecord>> _completer =
      Completer<AdminPagedResult<AdminContentRecord>>();

  @override
  Future<AdminPagedResult<AdminContentRecord>> fetchPage(
    AdminContentResourceConfig config, {
    required int page,
    required int pageSize,
    String query = '',
  }) {
    return _completer.future;
  }

  void complete() {
    if (_completer.isCompleted) return;
    _completer.complete(
      const AdminPagedResult<AdminContentRecord>(
        items: <AdminContentRecord>[],
        totalCount: 0,
      ),
    );
  }
}

class _FakeAdminContentRepository extends AdminContentRepository {
  int fetchRecordCount = 0;

  @override
  Future<AdminPagedResult<AdminContentRecord>> fetchPage(
    AdminContentResourceConfig config, {
    required int page,
    required int pageSize,
    String query = '',
  }) async {
    return const AdminPagedResult<AdminContentRecord>(
      items: <AdminContentRecord>[
        AdminContentRecord(
          id: 'place-1',
          idColumn: 'id_place',
          values: <String, dynamic>{
            'id_place': 'place-1',
            'name': 'Hoi An Ancient Town',
            'short_description': 'Visible row summary',
          },
        ),
      ],
      totalCount: 1,
    );
  }

  @override
  Future<AdminContentRecord> fetchRecord(
    AdminContentResourceConfig config,
    AdminContentRecord record,
  ) async {
    fetchRecordCount += 1;
    return const AdminContentRecord(
      id: 'place-1',
      idColumn: 'id_place',
      values: <String, dynamic>{
        'id_place': 'place-1',
        'name': 'Hoi An Ancient Town',
        'short_description': 'Visible row summary',
        'detailed_description': 'Full admin detail',
      },
    );
  }
}

class _ControlledSearchRepository extends AdminContentRepository {
  final Map<String, Completer<AdminPagedResult<AdminContentRecord>>> _pending =
      <String, Completer<AdminPagedResult<AdminContentRecord>>>{};

  List<String> get pendingQueries => _pending.keys.toList(growable: false);

  @override
  Future<AdminPagedResult<AdminContentRecord>> fetchPage(
    AdminContentResourceConfig config, {
    required int page,
    required int pageSize,
    String query = '',
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const AdminPagedResult<AdminContentRecord>(
        items: <AdminContentRecord>[
          AdminContentRecord(
            id: 'place-initial',
            idColumn: 'id_place',
            values: <String, dynamic>{
              'id_place': 'place-initial',
              'name': 'Initial Place',
            },
          ),
        ],
        totalCount: 1,
      );
    }

    final completer = Completer<AdminPagedResult<AdminContentRecord>>();
    _pending[trimmedQuery] = completer;
    return completer.future;
  }

  void completeQuery(String query, {required String name}) {
    final completer = _pending.remove(query);
    if (completer == null) {
      throw StateError('No pending query "$query".');
    }
    completer.complete(
      AdminPagedResult<AdminContentRecord>(
        items: <AdminContentRecord>[
          AdminContentRecord(
            id: 'place-$query',
            idColumn: 'id_place',
            values: <String, dynamic>{'id_place': 'place-$query', 'name': name},
          ),
        ],
        totalCount: 1,
      ),
    );
  }
}
