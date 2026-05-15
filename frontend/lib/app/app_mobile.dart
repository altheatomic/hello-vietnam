import 'package:flutter/material.dart';

import 'app.dart';
import 'router.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return App(router: buildRouter());
  }
}

