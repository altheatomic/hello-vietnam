import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final AppLanguageController controller = AppLanguageController.instance;

    return AppLanguageScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: controller.locale,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLanguage.values
                .map((AppLanguage language) => language.locale)
                .toList(growable: false),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
