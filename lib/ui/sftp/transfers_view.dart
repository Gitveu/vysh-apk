import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/transfer_queue.dart';
import '../../infra/platform/local_files.dart';

/// Список передач вкладки внизу SFTP-панели.
class TransfersView extends ConsumerWidget {
  const TransfersView({super.key, required this.tabId});

  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(transferQueueProvider).where((t) => t.tabId == tabId).toList();
    if (all.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final queue = ref.read(transferQueueProvider.notifier);
    final active = all.where((t) => t.isActive).length;
    final failed = all.where((t) => t.status == TransferStatus.failed).length;
    // Сначала активные, потом последние завершённые.
    final shown = [
      ...all.where((t) => t.isActive),
      ...all.reversed.where((t) => !t.isActive),
    ].take(50).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
            child: Row(
              children: [
                Icon(Icons.swap_vert, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  active > 0 ? 'Передачи: $active в работе' : 'Передачи завершены',
                  style: theme.textTheme.labelMedium,
                ),
                if (failed > 0) ...[
                  const SizedBox(width: 8),
                  Text('ошибок: $failed',
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.error)),
                ],
                const Spacer(),
                if (active > 0)
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => queue.cancelAllForTab(tabId),
                    child: const Text('Отменить все'),
                  ),
                if (all.length > active)
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => queue.clearFinished(tabId),
                    child: const Text('Очистить'),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: shown.length,
              itemBuilder: (context, i) => _TransferRow(
                t: shown[i],
                onCancel: () => queue.cancel(shown[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.t, required this.onCancel});

  final Transfer t;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant);
    final up = t.direction == TransferDirection.upload;

    final String info = switch (t.status) {
      TransferStatus.queued => 'в очереди',
      TransferStatus.running => t.total > 0
          ? '${formatBytes(t.done)} из ${formatBytes(t.total)} · ${formatBytes(t.bytesPerSecond)}/с'
          : formatBytes(t.done),
      TransferStatus.done => formatBytes(t.total),
      TransferStatus.failed => t.error ?? 'ошибка',
      TransferStatus.cancelled => 'отменено',
    };

    final Widget trailing = switch (t.status) {
      TransferStatus.queued || TransferStatus.running => IconButton(
          tooltip: 'Отменить',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: onCancel,
          icon: const Icon(Icons.close),
        ),
      TransferStatus.done => IconButton(
          tooltip: up ? 'Готово' : 'Показать в папке',
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          onPressed: up ? null : () => LocalFiles.reveal(t.localPath),
          icon: Icon(up ? Icons.check : Icons.folder_open, color: Colors.green.shade500),
        ),
      TransferStatus.failed => Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.error_outline, size: 16, color: scheme.error),
        ),
      TransferStatus.cancelled => const SizedBox(width: 32),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                if (t.status == TransferStatus.running)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: LinearProgressIndicator(
                      value: t.progress,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Text(info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.status == TransferStatus.failed
                        ? small.copyWith(color: scheme.error)
                        : small),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
