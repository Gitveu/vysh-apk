import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'domain/services/ports_providers.dart';
import 'infra/storage/app_paths.dart';
import 'ui/dialogs/session_prompt_dialogs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    // Только заголовок, стартовый и минимальный размер.
    // Позицию окна не трогаем — пусть решает оконный менеджер.
    const options = WindowOptions(
      title: 'vysh',
      size: Size(1200, 760),
      minimumSize: Size(640, 420),
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
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
