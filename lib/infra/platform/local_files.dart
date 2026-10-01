import 'dart:io';

/// Работа с локальными файлами и системными приложениями.
class LocalFiles {
  LocalFiles._();

  static String get _home {
    final env = Platform.environment;
    return env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
  }

  static String join(String a, String b) =>
      a.endsWith(Platform.pathSeparator) ? '$a$b' : '$a${Platform.pathSeparator}$b';

  /// Папка «Загрузки» по умолчанию.
  static String defaultDownloadsDir() {
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
  }

  /// Свободное имя: file.txt → file (1).txt, если такой уже есть.
  static String uniquePath(String dir, String name) {
    var candidate = join(dir, name);
    if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) return candidate;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var i = 1; i < 1000; i++) {
      candidate = join(dir, '$base ($i)$ext');
      if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) return candidate;
    }
    return join(dir, '$base-${DateTime.now().millisecondsSinceEpoch}$ext');
  }

  /// Временная папка для файлов, открытых на редактирование.
  static Future<Directory> editTempDir() async {
    final dir = Directory(join(Directory.systemTemp.path,
        'vysh-edit-${DateTime.now().microsecondsSinceEpoch}'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Открыть файл программой по умолчанию.
  static Future<void> openWithSystem(String path) async {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', path], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    }
  }

  /// Показать файл/папку в файловом менеджере.
  static Future<void> reveal(String path) async {
    if (Platform.isWindows) {
      final isDir = Directory(path).existsSync();
      await Process.start('explorer', isDir ? [path] : ['/select,$path'],
          mode: ProcessStartMode.detached);
    } else {
      final target = Directory(path).existsSync() ? path : File(path).parent.path;
      await openWithSystem(target);
    }
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
