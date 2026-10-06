import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/models/app_settings.dart';
import '../domain/services/external_colors_controller.dart';
import '../domain/services/monet_colors_provider.dart';
import '../domain/services/settings_controller.dart';
import '../infra/platform/desktop_env.dart';
import '../ui/shell/app_shell.dart';
import '../ui/shell/ui_state.dart';
import '../ui/theme/app_theme.dart';

/// Корневой навигатор - через него сессии показывают диалоги
/// (пароль, ключ сервера) из не-UI кода.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class VyshApp extends ConsumerWidget {
  const VyshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ext = ref.watch(externalColorsProvider);
    final monet = ref.watch(monetColorsProvider).value;

    // Переключили режим заголовка - применяем сразу, без перезапуска.
    ref.listen<bool>(customTitleBarProvider, (_, custom) {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        windowManager.setTitleBarStyle(
          custom ? TitleBarStyle.hidden : TitleBarStyle.normal,
          windowButtonVisibility: !custom,
        );
      }
    });

    // Android: выбора цветов нет — только Monet, при недоступности фиолетовый.
    // Прочие платформы: как раньше, акцент системы / доты / свой цвет.
    final e = DesktopEnv.isMobile ? null : (s.colorSource == ColorSource.preset ? null : ext);
    final seed = DesktopEnv.isMobile
        ? (monet?.accentPrimary ?? const Color(0xFF6750A4))
        : (e?.seed ?? Color(s.seedColor));

    // Доты задают тёмный/светлый режим - следуем им, если тема «Системная».
    var mode = s.themeMode;
    final dotsBrightness = e?.brightness;
    if (mode == ThemeMode.system && dotsBrightness != null) {
      mode = dotsBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    }

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
