import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/version.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/app_strings.dart';
import '../../domain/services/settings_controller.dart';
import '../../infra/platform/desktop_env.dart';
import '../theme/app_theme.dart';
import 'appearance_sections.dart';
import 'clipboard_section.dart';
import 'performance_section.dart';
import 'setting_row.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final strings = AppStrings.of(context, s.language);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile = DesktopEnv.isMobile;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        20,
        isMobile ? 16 : 28,
        28,
      ),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  icon: Icons.palette_outlined,
                  title: strings.appearanceSection,
                  children: [
                    // На Android весь выбор цветов вырезан: только Monet
                    // (или фиолетовый fallback), без сегментов и свотчей.
                    SettingRow(
                      label: strings.themeTitle,
                      // Сегменты должны занять всю ширину карточки, а подпись
                      // сжиматься, а не резаться многоточием.
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            textStyle: WidgetStatePropertyAll(
                              TextStyle(fontSize: 13),
                            ),
                          ),
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(strings.themeSystem),
                              ),
                              icon: const Icon(Icons.brightness_auto, size: 18),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(strings.themeLight),
                              ),
                              icon: const Icon(Icons.light_mode_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(strings.themeDark),
                              ),
                              icon: const Icon(Icons.dark_mode_outlined, size: 18),
                            ),
                          ],
                          selected: {s.themeMode},
                          onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
                        ),
                      ),
                    ),
                    if (!DesktopEnv.isMobile) const ColorSourceSection(),
                    const TitleBarSection(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.compactUi),
                      value: s.compact,
                      onChanged: ctrl.setCompact,
                    ),
                  ],
                ),
                _Section(
                  icon: Icons.dns_outlined,
                  title: strings.hostsSection,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.pingHostsTitle),
                      subtitle: Text(strings.pingHostsDesc),
                      value: s.pingHosts,
                      onChanged: ctrl.setPingHosts,
                    ),
                    const PingSettings(),
                    const SizedBox(height: 8),
                    SettingRow(
                      label: strings.keepAliveGlobalTitle,
                      child: DropdownButton<int>(
                        value: s.keepAliveSeconds,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(strings.keepAliveOff),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text(strings.keepAliveSecondsVal(15)),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text(strings.keepAliveSecondsVal(30)),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text(strings.keepAliveRecom),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text(
                              strings.isRu
                                  ? '120 сек (2 мин)'
                                  : '120 sec (2 min)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 300,
                            child: Text(
                              strings.isRu
                                  ? '300 сек (5 мин)'
                                  : '300 sec (5 min)',
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            v != null ? ctrl.setKeepAliveSeconds(v) : null,
                      ),
                    ),
                  ],
                ),
                _Section(
                  icon: Icons.terminal,
                  title: strings.terminalSection,
                  children: [
                    SettingRow(
                      label: strings.fontSizeTitle,
                      child: SizedBox(
                        width: 320,
                        child: Row(
                          children: [
                            Expanded(
                              child: Slider(
                                min: 8,
                                max: 32,
                                divisions: 24,
                                value: s.terminalFontSize
                                    .clamp(8, 32)
                                    .toDouble(),
                                label: s.terminalFontSize.round().toString(),
                                onChanged: ctrl.setTerminalFontSize,
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${s.terminalFontSize.round()}',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'root@server:~\$ htop',
                        style: monoStyle(
                          context,
                          size: s.terminalFontSize,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.rememberTerminalFontSizeTitle),
                      subtitle: Text(strings.rememberTerminalFontSizeDesc),
                      value: s.rememberTerminalFontSize,
                      onChanged: ctrl.setRememberTerminalFontSize,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.accessoryBarTitle),
                      subtitle: Text(strings.accessoryBarDesc),
                      value: s.showAccessoryBar,
                      onChanged: ctrl.setShowAccessoryBar,
                    ),
                    const SizedBox(height: 8),
                    const ClipboardSection(),
                  ],
                ),
                _Section(
                  icon: Icons.speed,
                  title: strings.isRu ? 'Производительность' : 'Performance',
                  children: const [PerformanceSection()],
                ),
                if (!isMobile) ...[
                  _Section(
                    icon: Icons.language,
                    title: strings.languageTitle,
                    children: [
                      SettingRow(
                        label: strings.languageTitle,
                        child: DropdownButton<AppLanguage>(
                          value: s.language,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            DropdownMenuItem(
                              value: AppLanguage.auto,
                              child: Text(strings.languageAuto),
                            ),
                            DropdownMenuItem(
                              value: AppLanguage.ru,
                              child: Text(strings.languageRu),
                            ),
                            DropdownMenuItem(
                              value: AppLanguage.en,
                              child: Text(strings.languageEn),
                            ),
                          ],
                          onChanged: (v) =>
                              v != null ? ctrl.setLanguage(v) : null,
                        ),
                      ),
                    ],
                  ),
                ],
                _Section(
                  icon: Icons.info_outline,
                  title: strings.aboutApp,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/icon/vysh_256.png',
                          width: 56,
                          height: 56,
                          errorBuilder: (_, __, ___) => const Icon(Icons.dns_rounded, size: 56),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'vysh $appVersion',
                                style: theme.textTheme.titleMedium,
                              ),
                              if (buildDate.isNotEmpty)
                                Text(
                                  'build $appBuildNumber · $buildDate',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                strings.appDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (!kIsWeb) const _MemoryUsage(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(title, style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Сколько памяти занимает процесс - чтобы сравнивать сборки и версии.
class _MemoryUsage extends StatefulWidget {
  const _MemoryUsage();

  @override
  State<_MemoryUsage> createState() => _MemoryUsageState();
}

class _MemoryUsageState extends State<_MemoryUsage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    int mb = 0;
    try {
      mb = (ProcessInfo.currentRss / (1024 * 1024)).round();
    } catch (_) {}
    final style = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Row(
      children: [
        Icon(Icons.memory, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            kDebugMode
                ? 'Память: $mb МБ (debug)'
                : 'Память: $mb МБ',
            style: style,
          ),
        ),
        IconButton(
          tooltip: 'Обновить',
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {}),
        ),
      ],
    );
  }
}
