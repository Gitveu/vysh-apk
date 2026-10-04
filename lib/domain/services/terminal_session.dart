import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:xterm2/core.dart';

import '../models/host.dart';
import '../models/session_tab.dart';
import '../ports/secret_store.dart';
import '../ports/session_prompts.dart';
import '../ports/sftp.dart';
import '../ports/ssh_transport.dart';
import '../../infra/platform/desktop_env.dart';
import 'known_hosts.dart';

/// Живая сессия одной вкладки: эмулятор терминала + SSH-соединение.
///
/// Жизненный цикл: connecting → ready → (lost | closed).
/// В состояниях lost/closed Enter в терминале переподключает.
/// Строка журнала подключения.
class ConnLogEntry {
  ConnLogEntry(this.text, {this.debug = false, this.error = false})
    : time = DateTime.now();
  final DateTime time;
  final String text;
  final bool debug;
  final bool error;
}

class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.host,
    required this.connector,
    required this.prompts,
    required this.secrets,
    required this.knownHosts,
    required this.onStatus,
    this.defaultKeepAliveSeconds = 60,
    String? initialPassword,
  }) : _memPassword = initialPassword;

  /// Пароль, введённый в этой сессии (в редакторе хоста или в диалоге).
  /// Живёт только в памяти — чтобы переподключение не спрашивало его заново.
  String? _memPassword;

  /// Интервал KeepAlive по умолчанию из настроек (в секундах).
  final int defaultKeepAliveSeconds;

  /// Хост; обновляется перед переподключением, если его отредактировали.
  Host host;
  final SshConnector connector;
  final SessionPrompts prompts;
  final SecretStore secrets;
  final KnownHosts knownHosts;
  final void Function(SessionStatus status) onStatus;

  final terminal = Terminal(maxLines: 10000);

  SessionStatus _status = SessionStatus.connecting;
  SessionStatus get status => _status;

  String? _serverVersion;
  String? get serverVersion => _serverVersion;

  /// Журнал последней попытки подключения.
  final connLog = <ConnLogEntry>[];

  /// Ошибка последней попытки (null — подключились или ещё подключаемся).
  SshFailure? lastFailure;

  /// Соединение оборвалось уже после успешного входа.
  bool droppedAfterReady = false;

  /// Модификаторы для виртуальной клавиатуры (как в Termux).
  bool ctrlModifier = false;
  bool altModifier = false;
  VoidCallback? onModifiersChanged;

  /// Текст текущего ввода пользователя без prompt и вывода shell.
  String clientTypedCommand = '';

  void toggleCtrl() {
    ctrlModifier = !ctrlModifier;
    onModifiersChanged?.call();
  }

  void toggleAlt() {
    altModifier = !altModifier;
    onModifiersChanged?.call();
  }

  void resetModifiers() {
    if (ctrlModifier || altModifier) {
      ctrlModifier = false;
      altModifier = false;
      onModifiersChanged?.call();
    }
  }

  /// Отправляет комбинацию Ctrl (например, \x03 для Ctrl+C) сразу в терминал/shell.
  void sendCtrlChar(String char) {
    ctrlModifier = false;
    onModifiersChanged?.call();

    final mapped = mapToCtrlChar(char) ?? char.toUpperCase();
    final code = mapped.codeUnitAt(0);
    int? byte;
    if (code >= 65 && code <= 90) {
      byte = code - 64;
    } else if (code >= 97 && code <= 122) {
      byte = code - 96;
    } else if (code == 91) {
      byte = 27; // ESC / ^[
    } else if (code == 92) {
      byte = 28; // ^\
    } else if (code == 93) {
      byte = 29; // ^]
    } else if (code == 94) {
      byte = 30; // ^^
    } else if (code == 95) {
      byte = 31; // ^_
    } else if (code == 32 || code == 64) {
      byte = 0; // ^@ or space
    }

    if (byte != null) {
      _updateClientTypedCommand(String.fromCharCode(byte));
      if (_shell != null) {
        _shell?.write(Uint8List.fromList([byte]));
      }
    }
  }

  /// Преобразует входную строку или клавишу в символ комбинации Ctrl (A-Z и др.).
  /// Поддерживает английские буквы и соответствующие клавиши русской раскладки QWERTY.
  static String? mapToCtrlChar(String input) {
    if (input.isEmpty) return null;
    final ch = input[0];
    final code = ch.codeUnitAt(0);
    if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
      return ch.toUpperCase();
    }
    const cyrillicToEn = <String, String>{
      'ф': 'A', 'Ф': 'A',
      'и': 'B', 'И': 'B',
      'с': 'C', 'С': 'C',
      'в': 'D', 'В': 'D',
      'у': 'E', 'У': 'E',
      'а': 'F', 'А': 'F',
      'п': 'G', 'П': 'G',
      'р': 'H', 'Р': 'H',
      'ш': 'I', 'Ш': 'I',
      'о': 'J', 'О': 'J',
      'л': 'K', 'Л': 'K',
      'д': 'L', 'Д': 'L',
      'ь': 'M', 'Ь': 'M',
      'т': 'N', 'Т': 'N',
      'щ': 'O', 'Щ': 'O',
      'з': 'P', 'З': 'P',
      'й': 'Q', 'Й': 'Q',
      'к': 'R', 'К': 'R',
      'ы': 'S', 'Ы': 'S',
      'е': 'T', 'Е': 'T',
      'г': 'U', 'Г': 'U',
      'м': 'V', 'М': 'V',
      'ц': 'W', 'Ц': 'W',
      'ч': 'X', 'Ч': 'X',
      'н': 'Y', 'Н': 'Y',
      'я': 'Z', 'Я': 'Z',
      'х': '[', 'Х': '[',
      'ъ': ']', 'Ъ': ']',
    };
    if (cyrillicToEn.containsKey(ch)) {
      return cyrillicToEn[ch];
    }
    if (ch == '[' || ch == ']' || ch == '\\' || ch == '^' || ch == '_' || ch == '@' || ch == ' ') {
      return ch;
    }
    return null;
  }

  void sendDirect(String text) {
    _updateClientTypedCommand(text);
    _shell?.write(utf8.encode(text));
  }

  void _updateClientTypedCommand(String text) {
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);

      if (code == 13 || code == 10 || code == 3 || code == 21) {
        clientTypedCommand = '';
      } else if (code == 23) {
        final trimmed = clientTypedCommand.trimRight();
        final lastSpace = trimmed.lastIndexOf(' ');
        clientTypedCommand = lastSpace >= 0
            ? trimmed.substring(0, lastSpace + 1)
            : '';
      } else if (code == 127 || code == 8) {
        if (clientTypedCommand.isNotEmpty) {
          clientTypedCommand = clientTypedCommand.substring(
            0,
            clientTypedCommand.length - 1,
          );
        }
      } else if (code >= 32) {
        clientTypedCommand += String.fromCharCode(code);
      }
    }
  }

  void _log(String text, {bool debug = false, bool error = false}) {
    connLog.add(ConnLogEntry(text, debug: debug, error: error));
    if (connLog.length > 2000) connLog.removeRange(0, connLog.length - 2000);
  }

  SshTransport? _transport;
  SshShell? _shell;
  Future<SftpSession>? _sftp;

  /// Подписки на файлы, открытые «локально» (автозагрузка при сохранении).
  final editWatchers = <StreamSubscription<Object?>>[];
  StreamSubscription<String>? _outputSub;
  bool _connecting = false;
  bool _disposed = false;

  // ─── Публичное API ────────────────────────────────────────────────

  Future<void> connect() async {
    if (_connecting || _disposed) return;
    _connecting = true;
    _teardown();
    connLog.clear();
    lastFailure = null;
    droppedAfterReady = false;
    _log('Подключение к ${host.displayAddress} (${host.auth.name})');
    _setStatus(SessionStatus.connecting);
    terminal.onOutput = null;
    _info('Подключение к ${host.displayAddress}…');

    try {
      final transport = await _connectWithRetries();
      if (_disposed) {
        await transport.close();
        return;
      }
      _transport = transport;
      _serverVersion = transport.serverVersion;

      final shell = await transport.openShell(
        columns: max(terminal.viewWidth, 20),
        rows: max(terminal.viewHeight, 5),
      );
      _shell = shell;

      terminal.onOutput = (data) {
        if (ctrlModifier && data.isNotEmpty) {
          if (data == '\x1b') {
            resetModifiers();
            return;
          }
          final mapped = mapToCtrlChar(data);
          if (mapped != null) {
            sendCtrlChar(mapped);
            return;
          }
        }

        _updateClientTypedCommand(data);
        var output = data;
        if (altModifier && output.isNotEmpty) {
          output = '\x1b$output';
          altModifier = false;
          onModifiersChanged?.call();
        }
        shell.write(utf8.encode(output));
      };
      terminal.onResize = (w, h, _, _) {
        if (w >= 10 && h >= 2) shell.resize(w, h);
      };
      _outputSub = shell.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(terminal.write);

      _setStatus(SessionStatus.ready);

      shell.done.then((_) => _onEnded(clean: true));
      transport.done.then((_) => _onEnded(clean: false));
    } on SshFailure catch (e) {
      if (_disposed) return;
      if (e.kind == SshFailureKind.cancelled) {
        _info('Подключение отменено.');
      } else {
        _error(e.message);
      }
      lastFailure = e;
      _setStatus(SessionStatus.lost);
      _offerReconnect();
    } catch (e) {
      if (_disposed) return;
      _error('Неожиданная ошибка: $e');
      lastFailure = SshFailure(SshFailureKind.other, 'Неожиданная ошибка: $e');
      _setStatus(SessionStatus.lost);
      _offerReconnect();
    } finally {
      _connecting = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final w in editWatchers) {
      w.cancel();
    }
    editWatchers.clear();
    _teardown();
    super.dispose();
  }

  /// Сбросить SFTP-канал (после ошибки), следующий [sftp] откроет новый.
  void resetSftp() {
    final old = _sftp;
    _sftp = null;
    old?.then((s) => s.close()).catchError((_) {});
  }

  /// SFTP поверх текущего соединения (открывается один раз и переиспользуется).
  Future<SftpSession> sftp() {
    final transport = _transport;
    if (transport == null || _status != SessionStatus.ready) {
      return Future.error(const SftpFailure('Нет соединения с сервером'));
    }
    return _sftp ??= transport
        .openSftp()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const SftpFailure(
            'Сервер не ответил по SFTP. Возможно, на нём нет sftp-server '
            '(на OpenWrt: opkg install openssh-sftp-server).',
          ),
        )
        .catchError((Object e) {
          _sftp = null;
          throw e;
        });
  }

  // ─── Подключение ──────────────────────────────────────────────────

  Future<SshTransport> _connectWithRetries() async {
    var keys = await _loadKeys();

    String? password;
    var passwordFromStore = false;
    var rememberPassword = false;
    var cancelled = false;

    if (host.auth == AuthMethod.password) {
      password = _memPassword;
      if (password == null) {
        password = await secrets.read(passwordKey(host.id));
        passwordFromStore = password != null;
      }
    }

    Future<String?> providePassword(bool retry) async {
      if (password != null) return password;
      final answer = await prompts.askPassword(host, retry: retry);
      if (answer == null) {
        cancelled = true;
        return null;
      }
      password = answer.value;
      rememberPassword = answer.remember;
      return password;
    }

    final keepSec = host.keepAliveSeconds ?? defaultKeepAliveSeconds;
    final keepDuration = keepSec <= 0
        ? Duration.zero
        : Duration(seconds: keepSec);

    for (var attempt = 0; attempt < 3; attempt++) {
      final retry = attempt > 0;
      try {
        final transport = await connector.connect(
          SshConnectRequest(
            address: host.address,
            port: host.port,
            username: host.username,
            keys: keys,
            keepAliveInterval: keepDuration,
            password: host.auth == AuthMethod.password
                ? () => providePassword(retry)
                : null,
            interactive: (name, instruction, list) async {
              // Обычный «Password:» через keyboard-interactive — отвечаем паролем.
              if (host.auth == AuthMethod.password &&
                  list.length == 1 &&
                  !list.first.echo) {
                final p = await providePassword(retry);
                return p == null ? null : [p];
              }
              final answers = await prompts.askInteractive(
                host,
                name,
                instruction,
                list,
              );
              if (answers == null) cancelled = true;
              return answers;
            },
            verifyHostKey: _verifyHostKey,
            onBanner: (b) =>
                terminal.write('${b.replaceAll('\n', '\r\n')}\r\n'),
            onLog: (line, debug) => _log(line, debug: debug),
          ),
        );

        _memPassword = password;
        if (rememberPassword && password != null) {
          try {
            await secrets.write(passwordKey(host.id), password!);
          } catch (_) {
            _info(
              'Не удалось сохранить пароль: системное хранилище недоступно.',
            );
          }
        }
        return transport;
      } on SshFailure catch (e) {
        if (cancelled) {
          throw const SshFailure(SshFailureKind.cancelled, 'Отменено');
        }
        switch (e.kind) {
          case SshFailureKind.auth when host.auth == AuthMethod.password:
            if (passwordFromStore) {
              passwordFromStore = false;
              await secrets.delete(passwordKey(host.id));
            }
            password = null;
            _memPassword = null;
            _error('Неверный логин или пароль.');
          case SshFailureKind.keyPassphrase:
            await secrets.delete(passphraseKey(host.id));
            _error(e.message);
            keys = await _loadKeys(retry: true);
          default:
            rethrow;
        }
      }
    }
    throw const SshFailure(
      SshFailureKind.auth,
      'Не удалось войти после трёх попыток.',
    );
  }

  Future<bool> _verifyHostKey(String type, String fingerprint) async {
    final known = knownHosts.lookup(host.address, host.port);
    if (known != null && known.fingerprint == fingerprint) return true;

    final ok = await prompts.confirmHostKey(
      host,
      type: type,
      fingerprint: fingerprint,
      previous: known?.fingerprint,
    );
    if (ok) knownHosts.remember(host.address, host.port, type, fingerprint);
    return ok;
  }

  Future<List<SshKeySource>> _loadKeys({bool retry = false}) async {
    switch (host.auth) {
      case AuthMethod.password:
        return const [];

      case AuthMethod.key:
        final raw = (host.keyPath?.trim().isNotEmpty ?? false)
            ? host.keyPath!.trim()
            : '~/.ssh/id_ed25519';
        final path = expandHome(raw);
        final file = File(path);
        if (!await file.exists()) {
          throw SshFailure(
            SshFailureKind.config,
            'Файл ключа не найден: $path',
          );
        }
        final pem = await file.readAsString();
        if (pem.contains('PuTTY-User-Key-File')) {
          throw const SshFailure(
            SshFailureKind.config,
            'Ключи PuTTY (.ppk) пока не поддерживаются — экспортируйте ключ в формат OpenSSH в PuTTYgen.',
          );
        }
        String? passphrase;
        if (connector.isKeyEncrypted(pem)) {
          passphrase = retry
              ? null
              : await secrets.read(passphraseKey(host.id));
          if (passphrase == null) {
            final answer = await prompts.askPassphrase(host, raw, retry: retry);
            if (answer == null) {
              throw const SshFailure(SshFailureKind.cancelled, 'Отменено');
            }
            passphrase = answer.value;
            if (answer.remember) {
              try {
                await secrets.write(passphraseKey(host.id), passphrase);
              } catch (_) {}
            }
          }
        }
        return [SshKeySource(label: raw, pem: pem, passphrase: passphrase)];

      case AuthMethod.agent:
        // Пока без ssh-agent: берём стандартные незашифрованные ключи из ~/.ssh.
        final result = <SshKeySource>[];
        for (final name in const ['id_ed25519', 'id_ecdsa', 'id_rsa']) {
          final file = File(expandHome('~/.ssh/$name'));
          if (!await file.exists()) continue;
          final pem = await file.readAsString();
          if (connector.isKeyEncrypted(pem)) continue;
          result.add(SshKeySource(label: '~/.ssh/$name', pem: pem));
        }
        if (result.isEmpty) {
          throw const SshFailure(
            SshFailureKind.config,
            'В ~/.ssh не найдено незашифрованных ключей (id_ed25519, id_ecdsa, id_rsa).',
          );
        }
        return result;
    }
  }

  // ─── Завершение ───────────────────────────────────────────────────

  void _onEnded({required bool clean}) {
    if (_disposed || _status != SessionStatus.ready) return;
    _teardown();
    if (clean) {
      _info('Сессия завершена.');
      _setStatus(SessionStatus.closed);
    } else {
      _error('Соединение потеряно.');
      droppedAfterReady = true;
      lastFailure = const SshFailure(
        SshFailureKind.network,
        'Соединение с сервером потеряно',
      );
      _setStatus(SessionStatus.lost);
    }
    _offerReconnect();
  }

  void _offerReconnect() {
    _info(
      DesktopEnv.isDesktop
          ? 'Нажмите Enter, чтобы переподключиться.'
          : 'Нажмите «Переподключить», чтобы восстановить связь.',
    );
    terminal.onOutput = (data) {
      if (data.contains('\r') || data.contains('\n')) connect();
    };
  }

  void _teardown() {
    final sftp = _sftp;
    _sftp = null;
    sftp?.then((s) => s.close()).catchError((_) {});
    _outputSub?.cancel();
    _outputSub = null;
    _shell?.close();
    _shell = null;
    _transport?.close();
    _transport = null;
    terminal.onResize = null;
  }

  void _setStatus(SessionStatus s) {
    _status = s;
    if (_disposed) return;
    onStatus(s);
    notifyListeners();
  }

  // Служебные сообщения: тусклый текст с новой строки.
  void _info(String text) => terminal.write('\r\n\x1b[2m$text\x1b[0m\r\n');
  void _error(String text) {
    _log(text, error: true);
    terminal.write('\r\n\x1b[31m✗ $text\x1b[0m\r\n');
  }
}

/// `~/...` → домашняя папка (на Windows — %USERPROFILE%).
String expandHome(String path) {
  if (!path.startsWith('~')) return path;
  if (kIsWeb) return path;
  try {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    final rest = path.substring(1).replaceAll('/', Platform.pathSeparator);
    return '$home$rest';
  } catch (_) {
    return path;
  }
}
