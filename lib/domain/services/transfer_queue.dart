import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/host.dart';
import '../ports/sftp.dart';

enum TransferDirection { upload, download }

enum TransferStatus { queued, running, done, failed, cancelled }

class Transfer {
  const Transfer({
    required this.id,
    required this.tabId,
    required this.direction,
    required this.name,
    required this.localPath,
    required this.remotePath,
    this.total = 0,
    this.done = 0,
    this.status = TransferStatus.queued,
    this.error,
    this.bytesPerSecond = 0,
  });

  final String id;
  final String tabId;
  final TransferDirection direction;
  final String name;
  final String localPath;
  final String remotePath;
  final int total;
  final int done;
  final TransferStatus status;
  final String? error;
  final double bytesPerSecond;

  bool get isActive => status == TransferStatus.queued || status == TransferStatus.running;
  double? get progress => total > 0 ? (done / total).clamp(0, 1).toDouble() : null;

  Transfer copyWith({
    int? done,
    TransferStatus? status,
    String? error,
    double? bytesPerSecond,
  }) =>
      Transfer(
        id: id,
        tabId: tabId,
        direction: direction,
        name: name,
        localPath: localPath,
        remotePath: remotePath,
        total: total,
        done: done ?? this.done,
        status: status ?? this.status,
        error: error ?? this.error,
        bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      );
}

/// Тело передачи: выполняет работу, сообщает прогресс, уважает отмену.
typedef TransferRunner = Future<void> Function(CancelToken cancel, ProgressCallback onProgress);

class _Job {
  _Job(this.run, this.onDone);
  final TransferRunner run;
  final void Function()? onDone;
  final cancel = CancelToken();
}

final transferQueueProvider =
    NotifierProvider<TransferQueue, List<Transfer>>(TransferQueue.new);

/// Очередь SFTP-передач: не больше [maxParallel] одновременно.
class TransferQueue extends Notifier<List<Transfer>> {
  static const maxParallel = 3;
  final _jobs = <String, _Job>{};

  @override
  List<Transfer> build() => const [];

  String enqueue({
    required String tabId,
    required TransferDirection direction,
    required String name,
    required String localPath,
    required String remotePath,
    required int total,
    required TransferRunner run,
    void Function()? onDone,
  }) {
    final id = newId();
    _jobs[id] = _Job(run, onDone);
    state = [
      ...state,
      Transfer(
        id: id,
        tabId: tabId,
        direction: direction,
        name: name,
        localPath: localPath,
        remotePath: remotePath,
        total: total,
      ),
    ];
    _pump();
    return id;
  }

  void cancel(String id) {
    final t = state.where((t) => t.id == id).firstOrNull;
    if (t == null || !t.isActive) return;
    _jobs[id]?.cancel.cancel();
    if (t.status == TransferStatus.queued) {
      _jobs.remove(id);
      _update(id, (t) => t.copyWith(status: TransferStatus.cancelled));
    }
  }

  void cancelAllForTab(String tabId) {
    for (final t in state.where((t) => t.tabId == tabId && t.isActive).toList()) {
      cancel(t.id);
    }
  }

  void clearFinished(String tabId) {
    state = state.where((t) => t.tabId != tabId || t.isActive).toList();
  }

  void _pump() {
    var running = state.where((t) => t.status == TransferStatus.running).length;
    for (final t in state) {
      if (running >= maxParallel) break;
      if (t.status != TransferStatus.queued) continue;
      final job = _jobs[t.id];
      if (job == null) continue;
      running++;
      _start(t.id, job);
    }
  }

  void _start(String id, _Job job) {
    _update(id, (t) => t.copyWith(status: TransferStatus.running));
    final sw = Stopwatch()..start();
    var lastEmit = 0;
    var lastBytes = 0;
    var lastTime = 0;
    var speed = 0.0;

    void onProgress(int done) {
      final now = sw.elapsedMilliseconds;
      if (now - lastEmit < 120) return; // не чаще ~8 раз в секунду
      final dt = now - lastTime;
      if (dt > 0) {
        final instant = (done - lastBytes) * 1000 / dt;
        speed = speed == 0 ? instant : speed * 0.7 + instant * 0.3;
      }
      lastBytes = done;
      lastTime = now;
      lastEmit = now;
      _update(id, (t) => t.copyWith(done: done, bytesPerSecond: speed));
    }

    job.run(job.cancel, onProgress).then((_) {
      if (job.cancel.isCancelled) {
        _update(id, (t) => t.copyWith(status: TransferStatus.cancelled));
      } else {
        _update(id, (t) => t.copyWith(status: TransferStatus.done, done: t.total));
        job.onDone?.call();
      }
    }).catchError((Object e) {
      final cancelled = e is TransferCancelled || job.cancel.isCancelled;
      _update(
        id,
        (t) => t.copyWith(
          status: cancelled ? TransferStatus.cancelled : TransferStatus.failed,
          error: cancelled ? null : e.toString(),
        ),
      );
    }).whenComplete(() {
      _jobs.remove(id);
      _pump();
    });
  }

  void _update(String id, Transfer Function(Transfer) f) {
    if (!ref.mounted) return;
    state = [for (final t in state) t.id == id ? f(t) : t];
  }
}
