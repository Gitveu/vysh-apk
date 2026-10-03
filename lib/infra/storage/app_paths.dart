import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Где vysh хранит свои файлы (хосты, настройки, known_hosts).
class AppPaths {
  AppPaths._();

  static Directory? _configDir;

  static Directory get configDir {
    if (kIsWeb) return Directory('/vysh');
    try {
      return _configDir ?? Directory(_join(Directory.systemTemp.path, 'vysh'));
    } catch (_) {
      return Directory('/vysh');
    }
  }

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final path = await _resolve();
      final dir = Directory(path);
      await dir.create(recursive: true);
      _configDir = dir;
    } catch (_) {
      // Игнорируем ошибки файловой системы в web/sandbox
    }
  }

  static File file(String name) => File(_join(configDir.path, name));

  static Future<String> _resolve() async {
    if (kIsWeb) return 'vysh';
    try {
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
    } catch (_) {
      return 'vysh';
    }
  }

  static String _join(String a, String b) {
    if (kIsWeb) return '$a/$b';
    try {
      return '$a${Platform.pathSeparator}$b';
    } catch (_) {
      return '$a/$b';
    }
  }
}
