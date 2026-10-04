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

  void start() {
    scheduleMicrotask(() async {
      if (kIsWeb) {
        _out.add(
          'Сетевая диагностика через системные утилиты недоступна в веб-версии.',
        );
        await _out.close();
        return;
      }
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
      await _out.close();
    });
  }

  void stop() {
    _stopped = true;
    _process?.kill();
    _socket?.destroy();
  }

  Future<void> _checkPort() async {
    _out.add('Проверка TCP-порта $port на $host...');
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      _socket = s;
      sw.stop();
      _out.add('✓ Порт $port открыт (ответ за ${sw.elapsedMilliseconds} ms)');
      s.destroy();
    } catch (e) {
      sw.stop();
      _out.add('✗ Порт $port недоступен: $e');
    }
  }

  Future<void> _run(List<String> cmd) async {
    _out.add('\$ ${cmd.join(' ')}');
    try {
      final p = (!kIsWeb && Platform.isWindows)
          ? await Process.start('cmd', [
              '/c',
              'chcp 65001 >nul & ${cmd.join(' ')}',
            ])
          : await Process.start(
              cmd.first,
              cmd.sublist(1),
              environment: {'LC_ALL': 'C'},
            );
      _process = p;
      final lines = p.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (_stopped) break;
        if (line.trim().isNotEmpty) _out.add(line);
      }
      final err = await p.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      if (err.trim().isNotEmpty) _out.add(err);
      final code = await p.exitCode;
      if (code != 0) _out.add('Код завершения: $code');
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
