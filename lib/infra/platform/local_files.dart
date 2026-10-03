import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/app_paths.dart';

/// Работа с локальными файлами и системными приложениями.
class LocalFiles {
  LocalFiles._();

  static String get _home {
    if (kIsWeb) return '/Downloads';
    try {
      final env = Platform.environment;
      return env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
    } catch (_) {
      return '/Downloads';
    }
  }

  static String join(String a, String b) {
    if (kIsWeb) return '$a/$b';
    try {
      return a.endsWith(Platform.pathSeparator) ? '$a$b' : '$a${Platform.pathSeparator}$b';
    } catch (_) {
      return '$a/$b';
    }
  }

  /// Папка «Загрузки» по умолчанию.
  static String defaultDownloadsDir() {
    if (kIsWeb) return 'Downloads';
    try {
      if (Platform.isAndroid) {
        const androidDownload = '/storage/emulated/0/Download';
        if (Directory(androidDownload).existsSync()) {
          return androidDownload;
        }
        return AppPaths.configDir.path;
      }
      if (Platform.isLinux) {
        // XDG_DOWNLOAD_DIR из ~/.config/user-dirs.dirs (бывает «Загрузки»).
        try {
          final f = File(join(_home, '.config/user-dirs.dirs'));
          if (f.existsSync()) {
            final m = RegExp(r'^XDG_DOWNLOAD_DIR="(.+)"', multiLine: true)
                .firstMatch(f.readAsStringSync());
            if (m != null) return m.group(1)!.replaceAll(r'$HOME', _home);
          }
        } catch (_) {}
      }
      return join(_home, 'Downloads');
    } catch (_) {
      return 'Downloads';
    }
  }

  /// Свободное имя: file.txt → file (1).txt, если такой уже есть.
  static String makeAvailable(String dir, String name) {
    if (kIsWeb) return name;
    try {
      var candidate = join(dir, name);
      if (!File(candidate).existsSync()) return name;
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      for (var i = 1; i < 1000; i++) {
        final next = '$base ($i)$ext';
        if (!File(join(dir, next)).existsSync()) return next;
      }
      return name;
    } catch (_) {
      return name;
    }
  }

  /// Уникальный путь к файлу в указанной папке.
  static String uniquePath(String dir, String name) => join(dir, makeAvailable(dir, name));

  /// Временная папка для открытия файлов во внешнем редакторе.
  static Future<Directory> editTempDir() async {
    if (kIsWeb) return Directory('/tmp');
    try {
      final base = Directory.systemTemp.path;
      final dir = Directory(join(base, 'vysh-edit-${DateTime.now().millisecondsSinceEpoch}'));
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return Directory('/tmp');
    }
  }

  /// Открыть файл программой по умолчанию.
  static Future<void> openWithSystem(String path) async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
      }
    } catch (_) {}
  }

  /// Показать файл/папку в файловом менеджере.
  static Future<void> reveal(String path) async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        final isDir = Directory(path).existsSync();
        await Process.start('explorer', isDir ? [path] : ['/select,$path'],
            mode: ProcessStartMode.detached);
      } else if (Platform.isLinux || Platform.isMacOS) {
        final target = Directory(path).existsSync() ? path : File(path).parent.path;
        await openWithSystem(target);
      }
    } catch (_) {}
  }
}

String formatBytes(num bytes) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return i == 0 ? '${v.round()} ${units[i]}' : '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}
