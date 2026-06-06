import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(context.l10n.ui('Messages'))));
  }
}
