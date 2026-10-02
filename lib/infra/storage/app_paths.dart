import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Где vysh хранит свои файлы (хосты, настройки, known_hosts).
///
/// Всегда в профиле пользователя — неважно, откуда запущен exe.
/// Поэтому обновление = удалить старую папку с программой и распаковать
/// новую: хосты и настройки останутся.
///
/// * Android: `$documentsDir/vysh`
/// * Windows: `%APPDATA%\vysh`
/// * Linux: `$XDG_CONFIG_HOME/vysh` (обычно `~/.config/vysh`)
class AppPaths {
  AppPaths._();

  static Directory? _configDir;

  static Directory get configDir =>
      _configDir ?? Directory(_join(Directory.systemTemp.path, 'vysh'));

  static Future<void> init() async {
    final path = await _resolve();
    final dir = Directory(path);
    await dir.create(recursive: true);
    _configDir = dir;
  }

  static File file(String name) => File(_join(configDir.path, name));

  static Future<String> _resolve() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      return _join(docs.path, 'vysh');
    }
    final env = Platform.environment;
    if (Platform.isWindows) {
      final base = env['APPDATA'] ?? env['USERPROFILE'] ?? '.';
      return _join(base, 'vysh');
    }
    final xdg = env['XDG_CONFIG_HOME'];
    final base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : _join(env['HOME'] ?? '.', '.config');
    return _join(base, 'vysh');
  }

  static String _join(String a, String b) => '$a${Platform.pathSeparator}$b';
}
