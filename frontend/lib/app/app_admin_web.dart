import 'package:flutter/material.dart';

import 'app.dart';
import 'router_admin_web.dart';

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return App(router: buildAdminWebRouter());
  }
}

