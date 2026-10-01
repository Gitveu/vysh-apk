import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../domain/ports/sftp.dart';

/// SFTP на dartssh2.
class DartSsh2Sftp implements SftpSession {
  DartSsh2Sftp(this._c);

  final SftpClient _c;

  @override
  Future<String> home() => _guard(() => _c.absolute('.'));

  @override
  Future<List<RemoteEntry>> list(String path) => _guard(() async {
        final names = await _c.listdir(path);
        final entries = <RemoteEntry>[];
        for (final n in names) {
          if (n.filename == '.' || n.filename == '..') continue;
          entries.add(_entry(remoteJoin(path, n.filename), n.filename, n.attr));
        }
        // Для симлинков узнаём, указывают ли они на папку.
        await Future.wait([
          for (var i = 0; i < entries.length; i++)
            if (entries[i].isLink)
              _c.stat(entries[i].path).then((a) {
                final e = entries[i];
                entries[i] = RemoteEntry(
                  name: e.name,
                  path: e.path,
                  isDir: a.isDirectory,
                  isLink: true,
                  size: a.size ?? e.size,
                  modified: e.modified,
                  mode: e.mode,
                );
              }).catchError((_) {}),
        ]);
        return entries;
      });

  @override
  Future<RemoteEntry> stat(String path) =>
      _guard(() async => _entry(path, remoteBasename(path), await _c.stat(path)));

  RemoteEntry _entry(String path, String name, SftpFileAttrs a) => RemoteEntry(
        name: name,
        path: path,
        isDir: a.isDirectory,
        isLink: a.isSymbolicLink,
        size: a.size ?? 0,
        modified: a.modifyTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(a.modifyTime! * 1000),
        mode: a.mode?.value,
      );

  @override
  Future<void> mkdir(String path) => _guard(() => _c.mkdir(path));

  @override
  Future<void> rename(String from, String to) => _guard(() => _c.rename(from, to));

  @override
  Future<void> removeFile(String path) => _guard(() => _c.remove(path));

  @override
  Future<void> removeDir(String path) => _guard(() => _c.rmdir(path));

  @override
  Future<void> chmod(String path, int mode) =>
      _guard(() => _c.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode & 0xFFF))));

  @override
  Future<void> download(
    String remotePath,
    File local, {
    required CancelToken cancel,
    required ProgressCallback onProgress,
  }) =>
      _guard(() async {
        final file = await _c.open(remotePath);
        final sink = local.openWrite();
        var done = 0;
        try {
          await for (final chunk in file.read()) {
            if (cancel.isCancelled) throw const TransferCancelled();
            sink.add(chunk);
            done += chunk.length;
            onProgress(done);
          }
        } finally {
          await sink.flush();
          await sink.close();
          await file.close();
        }
      });

  @override
  Future<void> upload(
    File local,
    String remotePath, {
    required CancelToken cancel,
    required ProgressCallback onProgress,
  }) =>
      _guard(() async {
        final file = await _c.open(
          remotePath,
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
        );
        try {
          final stream = local
              .openRead()
              .map((c) => c is Uint8List ? c : Uint8List.fromList(c));
          final writer = file.write(stream, onProgress: onProgress);
          cancel.onCancel(() => writer.abort());
          await writer.done;
          if (cancel.isCancelled) throw const TransferCancelled();
        } finally {
          await file.close();
        }
      });

  @override
  Future<void> close() async {
    try {
      await _c.close();
    } catch (_) {}
  }

  /// Переводим ошибки SFTP в понятные сообщения.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on TransferCancelled {
      rethrow;
    } on SftpStatusError catch (e) {
      throw SftpFailure(switch (e.code) {
        2 => 'Нет такого файла или папки',
        3 => 'Нет прав доступа',
        4 => 'Операция не выполнена${e.message.isEmpty ? '' : ': ${e.message}'}',
        8 => 'Сервер не поддерживает эту операцию',
        11 => 'Файл уже существует',
        _ => e.message.isEmpty ? 'Ошибка SFTP (${e.code})' : e.message,
      });
    } on SftpError catch (e) {
      throw SftpFailure(e.message);
    } on FileSystemException catch (e) {
      throw SftpFailure('Локальный файл: ${e.osError?.message ?? e.message}');
    } on SSHError catch (e) {
      throw SftpFailure('Соединение: $e');
    }
  }
}
