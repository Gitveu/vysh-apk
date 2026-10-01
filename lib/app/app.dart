import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return MaterialApp(
      title: 'vysh',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: buildTheme(seed: seed, brightness: Brightness.light, compact: s.compact),
      darkTheme: buildTheme(seed: seed, brightness: Brightness.dark, compact: s.compact),
      themeAnimationDuration: const Duration(milliseconds: 250),
      home: const AppShell(),
    );
  }
}
