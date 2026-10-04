import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_settings.dart';
import '../domain/services/settings_controller.dart';
import '../ui/shell/app_shell.dart';
import '../ui/theme/app_theme.dart';

/// Корневой навигатор — через него сессии показывают диалоги
/// (пароль, ключ сервера) из не-UI кода.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class VyshApp extends ConsumerWidget {
  const VyshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final seed = Color(s.seedColor);

    // Доты задают тёмный/светлый режим — следуем им, если тема «Системная».
    final mode = s.themeMode;

    ThemeData theme(Brightness b) =>
        buildTheme(seed: seed, brightness: b, compact: s.compact, roles: null);

    return MaterialApp(
      title: 'vysh',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeAnimationDuration: const Duration(milliseconds: 300),
      locale: s.language == AppLanguage.ru
          ? const Locale('ru')
          : (s.language == AppLanguage.en ? const Locale('en') : null),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          final code = locale.languageCode.toLowerCase();
          if (code.startsWith('ru') ||
              code.startsWith('be') ||
              code.startsWith('uk')) {
            return const Locale('ru');
          }
        }
        return const Locale('en');
      },
      home: const AppShell(),
    );
  }
}
