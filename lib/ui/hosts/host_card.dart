import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/host.dart';
import '../../domain/services/hosts_controller.dart';
import '../../domain/services/settings_controller.dart';
import '../../domain/services/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'host_editor.dart';

class HostCard extends ConsumerWidget {
  const HostCard({super.key, required this.host});

  final Host host;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить хост?'),
        content: Text('«${host.title}» будет удалён из списка.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) ref.read(hostsProvider.notifier).remove(host.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = Color(host.color);

    return Card(
      child: InkWell(
        onTap: () => ref.read(tabsProvider.notifier).openHost(host),
        onSecondaryTap: () => showHostEditor(context, host: host),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.dns_rounded, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(host.displayAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(context, size: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (ref.watch(settingsProvider.select((s) => s.pingHosts)))
                _Reachability(host: host),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: (v) {
                  switch (v) {
                    case 'connect':
                      ref.read(tabsProvider.notifier).openHost(host);
                    case 'edit':
                      showHostEditor(context, host: host);
                    case 'duplicate':
                      showHostEditor(context, host: host, duplicate: true);
                    case 'forget':
                      ref.read(hostsProvider.notifier).forgetSecrets(host.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Сохранённый пароль для «${host.title}» удалён')),
                      );
                    case 'delete':
                      _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'connect', child: Text('Подключиться')),
                  PopupMenuItem(value: 'edit', child: Text('Изменить')),
                  PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
                  PopupMenuItem(value: 'forget', child: Text('Забыть пароль')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reachability extends ConsumerWidget {
  const _Reachability({required this.host});

  final Host host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ping = ref.watch(reachabilityProvider((host.address, host.port)));

    return ping.when(
      loading: () => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (ms) => Tooltip(
        message: ms == null
            ? 'Порт ${host.port} не отвечает'
            : 'Порт ${host.port} доступен за $ms мс',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (ms == null ? scheme.error : Colors.green).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ms == null ? 'нет' : '$ms мс',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ms == null ? scheme.error : Colors.green.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
