import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_strings.dart';
import '../../domain/services/settings_controller.dart';
import 'setting_row.dart';

class PingSettings extends ConsumerWidget {
  const PingSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final strings = AppStrings.of(context, s.language);

    if (!s.pingHosts) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          label: strings.isRu ? 'Интервал проверки' : 'Ping interval',
          child: SettingChoice<int>(
            value: s.pingIntervalSec,
            options: [
              (15, strings.isRu ? '15 с' : '15s'),
              (30, strings.isRu ? '30 с' : '30s'),
              (60, strings.isRu ? '1 мин' : '1 min'),
              (120, strings.isRu ? '2 мин' : '2 min'),
              (300, strings.isRu ? '5 мин' : '5 min'),
            ],
            onChanged: ctrl.setPingIntervalSec,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.isRu ? 'Только на экране' : 'Only when visible'),
          subtitle: Text(strings.isRu
              ? 'Не проверять хосты в фоне'
              : 'Do not check hosts in background'),
          value: s.pingOnlyVisible,
          onChanged: ctrl.setPingOnlyVisible,
        ),
      ],
    );
  }
}

class PerformanceSection extends ConsumerWidget {
  const PerformanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final strings = AppStrings.of(context, s.language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          label: strings.isRu ? 'История терминала' : 'Scrollback lines',
          child: SettingChoice<int>(
            value: s.scrollbackLines,
            options: [
              (1000, '1 000'),
              (5000, '5 000'),
              (10000, '10 000'),
              (50000, '50 000'),
              (100000, '100 000'),
              (1000000, strings.isRu ? '1 млн' : '1M'),
            ],
            onChanged: ctrl.setScrollbackLines,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
              strings.isRu ? 'Остановка скрытых вкладок' : 'Pause hidden tabs'),
          subtitle: Text(strings.isRu
              ? 'Экономить ресурсы для неактивных вкладок'
              : 'Save resources on inactive tabs'),
          value: s.pauseHiddenTabs,
          onChanged: ctrl.setPauseHiddenTabs,
        ),
        SettingRow(
          label: strings.isRu ? 'Отрисовка' : 'Renderer',
          child: SettingChoice<Renderer>(
            value: s.renderer,
            options: const [
              (Renderer.skia, 'Skia (меньше памяти)'),
              (Renderer.impeller, 'Impeller'),
            ],
            onChanged: ctrl.setRenderer,
          ),
        ),
      ],
    );
  }
}
