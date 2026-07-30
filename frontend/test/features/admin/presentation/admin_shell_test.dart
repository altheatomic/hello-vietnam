import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/admin/presentation/admin_shell.dart';

void main() {
  testWidgets('admin shell fits the browser viewport at 125 percent scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 850);
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const AdminShell(
          currentPath: '/admin/activities',
          child: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
