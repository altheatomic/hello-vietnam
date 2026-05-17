import 'package:flutter/material.dart';
import 'admin_router.dart';
import 'theme.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: buildAdminRouter(),
    );
  }
}
