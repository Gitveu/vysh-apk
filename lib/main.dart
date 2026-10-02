import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'domain/models/app_settings.dart';
import 'domain/services/ports_providers.dart';
import 'infra/platform/desktop_env.dart';
import 'infra/platform/window_placement.dart';
import 'infra/storage/app_paths.dart';
import 'infra/storage/json_store.dart';
import 'ui/dialogs/session_prompt_dialogs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // Настройки нужны до показа окна: от них зависит, чей будет заголовок.
    final raw = JsonStore('settings.json').readSync();
    final settings = raw is Map<String, Object?> ? AppSettings.fromJson(raw) : const AppSettings();
    final custom = DesktopEnv.useCustomTitleBar(settings.titleBarMode);

    final options = WindowOptions(
      title: 'vysh',
      minimumSize: WindowPlacement.minSize,
      titleBarStyle: custom ? TitleBarStyle.hidden : TitleBarStyle.normal,
      windowButtonVisibility: !custom,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      final maximize = await WindowPlacement.instance.restore();
      await windowManager.show();
      if (maximize) await windowManager.maximize();
      await windowManager.focus();
    });
  }

  runApp(ProviderScope(
    overrides: [
      sessionPromptsProvider.overrideWithValue(DialogSessionPrompts(rootNavigatorKey)),
    ],
    child: const VyshApp(),
  ));
}
