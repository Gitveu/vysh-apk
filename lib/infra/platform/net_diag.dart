import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum DiagKind { ping, traceroute, port }

/// Сетевая диагностика системными утилитами: ping, tracert/traceroute.
/// Вывод идёт потоком строк; [stop] прерывает.
class NetDiag {
  NetDiag(this.kind, this.host, this.port);

  final DiagKind kind;
  final String host;
  final int port;

  final _out = StreamController<String>.broadcast();
  Stream<String> get output => _out.stream;

  Process? _process;
  Socket? _socket;
  bool _stopped = false;

  Future<void> start() async {
    if (kIsWeb) {
      _out.add('Сетевая диагностика через системные утилиты недоступна в веб-версии.');
      await _out.close();
      return;
    }
    // Адрес уходит в командную строку - пускаем только безопасные символы.
    if (!RegExp(r'^[A-Za-z0-9.:_\-]+$').hasMatch(host)) {
      _out.add('Недопустимый адрес: $host');
      await _out.close();
      return;
    }
    try {
      switch (kind) {
        case DiagKind.port:
          await _checkPort();
        case DiagKind.ping:
          await _run(
            (!kIsWeb && Platform.isWindows)
                ? ['ping', '-n', '4', host]
                : ['ping', '-c', '4', '-W', '2', host],
          );
        case DiagKind.traceroute:
          if (!kIsWeb && Platform.isWindows) {
            await _run(['tracert', '-d', '-w', '1000', '-h', '30', host]);
          } else if (await _exists('traceroute')) {
            await _run(['traceroute', '-n', '-w', '2', '-q', '1', host]);
          } else if (await _exists('tracepath')) {
            await _run(['tracepath', '-n', host]);
          } else {
            _out.add(
              'Не найден ни traceroute, ни tracepath. Установите пакет traceroute.',
            );
          }
      }
    } catch (e) {
      _out.add('Ошибка диагностики: $e');
    } finally {
      await _out.close();
    }
  }

  void stop() {
    _stopped = true;
    _process?.kill();
    _socket?.destroy();
  }

  Future<void> _checkPort() async {
    for (var i = 1; i <= 3 && !_stopped; i++) {
      final sw = Stopwatch()..start();
      try {
        final s = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
        _socket = s;
        sw.stop();
        _out.add('TCP $host:$port: открыт, ${sw.elapsedMilliseconds} мс');
        s.destroy();
      } on SocketException catch (e) {
        _out.add('TCP $host:$port: ${e.osError?.message ?? e.message}');
      } catch (e) {
        _out.add('TCP $host:$port: $e');
      }
      if (i < 3 && !_stopped) await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _run(List<String> cmd) async {
    _out.add('\$ ${cmd.join(' ')}');
    try {
      final p = (!kIsWeb && Platform.isWindows)
          ? await Process.start('cmd', ['/c', 'chcp 65001 >nul & ${cmd.join(' ')}'])
          : await Process.start(cmd.first, cmd.sublist(1), environment: {'LC_ALL': 'C'});
      _process = p;
      final lines = p.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .where((l) => l.trim().isNotEmpty);
      final err = p.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .where((l) => l.trim().isNotEmpty);
      await Future.wait([
        lines.forEach(_out.add),
        err.forEach(_out.add),
      ]);
      final code = await p.exitCode;
      if (_stopped) {
        _out.add('[остановлено]');
      } else if (code != 0) {
        _out.add('[завершено с кодом $code]');
      }
    } catch (e) {
      _out.add('Не удалось запустить команду: $e');
    }
  }

  Future<bool> _exists(String bin) async {
    try {
      final r = await Process.run('which', [bin]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
