import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/admin_router.dart';

void main() {
  test('admin router registers the data freshness route', () {
    final GoRouter router = buildAdminRouter();
    addTearDown(router.dispose);

    final Set<String> paths = RouteBase.routesRecursively(
      router.configuration.routes,
    ).whereType<GoRoute>().map((GoRoute route) => route.path).toSet();

    expect(paths, contains('/admin/data-freshness'));
  });
}
