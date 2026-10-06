import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/platform/app_icon_manager.dart';

/// Цвета Monet с Android; null - не Android или система не отдала цвета.
/// Читается один раз при старте (обои на Android меняются редко,
/// а живое обновление требует перезапуска обоев/лаунчера).
final monetColorsProvider = FutureProvider<MonetColors?>((ref) async {
  return AppIconManager.getMonetColors();
});
