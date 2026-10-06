import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_strings.dart';
import '../../domain/models/host.dart';
import '../../domain/services/hosts_controller.dart';
import '../../domain/services/settings_controller.dart';
import '../../domain/services/tabs_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/context_menu.dart';
import '../widgets/modifiers.dart';
import 'host_editor.dart';

class HostCard extends ConsumerWidget {
  const HostCard({
    super.key,
    required this.host,
    this.selected = false,
    this.selecting = false,
    this.onToggleSelect,
  });

  final Host host;

  /// Карточка отмечена для массовых действий.
  final bool selected;

  /// Идёт выбор: клик отмечает карточку, а не подключается.
  final bool selecting;
  final VoidCallback? onToggleSelect;

  void _onTap(WidgetRef ref) {
    // Win/Meta не считаем: после Win+Shift+S он «залипал» и обычный клик
    // отмечал хост вместо подключения.
    if ((selecting || Modifiers.instance.ctrl) && onToggleSelect != null) {
      onToggleSelect!();
    } else {
      ref.read(tabsProvider.notifier).openHost(host);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteHostTitle),
        content: Text(strings.deleteHostDesc(host.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
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
    final lang = ref.watch(settingsProvider.select((s) => s.language));
    final strings = AppStrings.of(context, lang);

    return ContextMenuArea(
      child: Builder(
        builder: (areaContext) => Card(
          color: selected ? scheme.secondaryContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => _onTap(ref),
            onSecondaryTapUp: (d) => ContextMenuArea.of(
              areaContext,
            )?.open(d.globalPosition, _items(context, ref, strings)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(selected ? 22 : 14),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded, color: scheme.onPrimary, size: 24)
                        : Icon(Icons.dns_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          host.displayAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(
                            context,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ref.watch(
                    settingsProvider.select((s) => s.pingHosts),
                  )) ...[
                    const SizedBox(width: 8),
                    _Reachability(host: host, strings: strings),
                  ],
                  const SizedBox(width: 4),
                  if (selecting)
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onToggleSelect?.call(),
                    )
                  else
                    MenuIconButton(
                      tooltip: strings.actions,
                      items: _items(context, ref, strings),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _items(BuildContext context, WidgetRef ref, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    return [
      menuItem(
        strings.isRu ? 'Подключиться' : 'Connect',
        icon: Icons.play_arrow_rounded,
        onPressed: () => ref.read(tabsProvider.notifier).openHost(host),
      ),
      menuItem(
        strings.edit,
        icon: Icons.edit_outlined,
        onPressed: () => showHostEditor(context, host: host),
      ),
      menuItem(
        strings.duplicate,
        icon: Icons.copy_all_outlined,
        onPressed: () => showHostEditor(context, host: host, duplicate: true),
      ),
      if (onToggleSelect != null)
        menuItem(
          selected
              ? (strings.isRu ? 'Снять выбор' : 'Deselect')
              : (strings.isRu ? 'Выбрать' : 'Select'),
          icon: Icons.check_box_outlined,
          onPressed: onToggleSelect,
        ),
      menuItem(
        strings.forgetPassword,
        icon: Icons.key_off_outlined,
        onPressed: () {
          ref.read(hostsProvider.notifier).forgetSecrets(host.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.isRu
                    ? 'Сохранённый пароль для «${host.title}» удалён'
                    : 'Saved password for «${host.title}» removed',
              ),
            ),
          );
        },
      ),
      menuDivider(),
      menuItem(
        strings.delete,
        icon: Icons.delete_outline,
        color: scheme.error,
        onPressed: () => _confirmDelete(context, ref, strings),
      ),
    ];
  }
}

class _Reachability extends ConsumerWidget {
  const _Reachability({required this.host, required this.strings});

  final Host host;
  final AppStrings strings;

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
            ? (strings.isRu
                  ? 'Порт ${host.port} не отвечает'
                  : 'Port ${host.port} is unreachable')
            : (strings.isRu
                  ? 'Порт ${host.port} доступен за $ms мс'
                  : 'Port ${host.port} reachable in ${ms}ms'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (ms == null ? scheme.error : Colors.green).withValues(
              alpha: 0.14,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ms == null ? 'нет' : (strings.isRu ? '$ms мс' : '${ms}ms'),
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
