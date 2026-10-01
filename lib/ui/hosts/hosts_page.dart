import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/host.dart';
import '../../domain/services/hosts_controller.dart';
import '../../domain/services/settings_controller.dart';
import '../../domain/services/tabs_controller.dart';
import '../shell/home_switcher.dart';
import '../shell/ui_state.dart';
import 'host_card.dart';
import 'host_editor.dart';

class HostsPage extends ConsumerStatefulWidget {
  const HostsPage({super.key});

  @override
  ConsumerState<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends ConsumerState<HostsPage> {
  final _search = TextEditingController();
  String _query = '';
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    // Пока главная открыта и проверка включена — обновляем доступность раз в 30 с.
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ref.read(settingsProvider).pingHosts) {
        ref.invalidate(reachabilityProvider);
      }
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _matches(Host h) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return h.title.toLowerCase().contains(q) ||
        h.address.toLowerCase().contains(q) ||
        h.username.toLowerCase().contains(q) ||
        h.group.toLowerCase().contains(q);
  }

  void _connectQuick(Host host) {
    ref.read(tabsProvider.notifier).openHost(host);
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(hostsProvider);
    final theme = Theme.of(context);
    final filtered = hosts.where(_matches).toList();
    final quick = filtered.isEmpty ? Host.tryParseQuick(_query) : null;

    // Группировка: сначала именованные группы по алфавиту, затем «без группы».
    final groups = <String, List<Host>>{};
    for (final h in filtered) {
      groups.putIfAbsent(h.group.trim(), () => []).add(h);
    }
    final groupNames = groups.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    for (final list in groups.values) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const HomeSwitcher(),
              const SizedBox(width: 16),
              const Spacer(),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SearchBar(
                    controller: _search,
                    focusNode: ref.watch(hostSearchFocusProvider),
                    hintText: 'Поиск или user@host:port',
                    elevation: const WidgetStatePropertyAll(0),
                    constraints: const BoxConstraints(minHeight: 44),
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                    onChanged: (v) => setState(() => _query = v.trim()),
                    onSubmitted: (_) {
                      if (filtered.length == 1) {
                        ref.read(tabsProvider.notifier).openHost(filtered.first);
                      } else if (quick != null) {
                        _connectQuick(quick);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => showHostEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Новый хост'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: hosts.isEmpty
                ? _EmptyState(onAdd: () => showHostEditor(context))
                : filtered.isEmpty
                    ? _NoResults(query: _query, quick: quick, onQuick: _connectQuick)
                    : CustomScrollView(
                        slivers: [
                          for (final g in groupNames) ...[
                            if (groupNames.length > 1 || g.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                                  child: Text(
                                    g.isEmpty ? 'Без группы' : g,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            SliverGrid(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 360,
                                mainAxisExtent: 84,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => HostCard(host: groups[g]![i]),
                                childCount: groups[g]!.length,
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(Icons.dns_rounded, size: 44,
                color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text('Пока нет ни одного хоста', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Добавьте сервер по адресу и логину\nили введите user@host в поиске для быстрого подключения',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Добавить хост'),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.quick, required this.onQuick});

  final String query;
  final Host? quick;
  final ValueChanged<Host> onQuick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ничего не найдено по «$query»',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (quick != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onQuick(quick!),
                icon: const Icon(Icons.bolt),
                label: Text('Подключиться к ${quick!.displayAddress}'),
              ),
              const SizedBox(height: 6),
              Text('Enter — подключиться без сохранения',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ],
        ),
      ),
    );
  }
}
