import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/version.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/app_strings.dart';
import '../../domain/services/settings_controller.dart';
import '../../infra/platform/desktop_env.dart';
import '../../infra/platform/local_files.dart';
import '../../infra/storage/app_paths.dart';
import '../theme/app_theme.dart';
import 'appearance_sections.dart';
import 'app_icon_picker_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final strings = AppStrings.of(context, s.language);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
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
                    _Row(
                      title: strings.themeTitle,
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(strings.themeSystem),
                            icon: const Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(strings.themeLight),
                            icon: const Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(strings.themeDark),
                            icon: const Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {s.themeMode},
                        onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const ColorSourceSection(),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.density_medium),
                      title: Text(strings.compactUi),
                      value: s.compact,
                      onChanged: ctrl.setCompact,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.app_shortcut_outlined),
                      title: Text(strings.appIconTitle),
                      subtitle: Text(switch (s.appIcon) {
                        'monet' => strings.appIconMonet,
                        _ => strings.appIconDefault,
                      }),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AppIconPickerPage()),
                      ),
                    ),
                  ],
                ),
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                  _Section(
                    icon: Icons.web_asset,
                    title: strings.windowSection,
                    children: const [TitleBarSection()],
                  ),
                _Section(
                  icon: Icons.dns_outlined,
                  title: strings.hostsSection,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.network_ping),
                      title: Text(strings.pingHostsTitle),
                      subtitle: Text(strings.pingHostsDesc),
                      value: s.pingHosts,
                      onChanged: ctrl.setPingHosts,
                    ),
                    const SizedBox(height: 8),
                    _Row(
                      title: strings.keepAliveGlobalTitle,
                      child: DropdownButton<int>(
                        value: s.keepAliveSeconds,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          DropdownMenuItem(value: 0, child: Text(strings.keepAliveOff)),
                          DropdownMenuItem(value: 15, child: Text(strings.keepAliveSecondsVal(15))),
                          DropdownMenuItem(value: 30, child: Text(strings.keepAliveSecondsVal(30))),
                          DropdownMenuItem(value: 60, child: Text(strings.keepAliveRecom)),
                          DropdownMenuItem(value: 120, child: Text(strings.isRu ? '120 сек (2 мин)' : '120 sec (2 min)')),
                          DropdownMenuItem(value: 300, child: Text(strings.isRu ? '300 сек (5 мин)' : '300 sec (5 min)')),
                        ],
                        onChanged: (v) => v != null ? ctrl.setKeepAliveSeconds(v) : null,
                      ),
                    ),
                  ],
                ),
                _Section(
                  icon: Icons.terminal,
                  title: strings.terminalSection,
                  children: [
                    _Row(
                      title: strings.fontSizeTitle,
                      child: SizedBox(
                        width: 320,
                        child: Row(
                          children: [
                            Expanded(
                              child: Slider(
                                min: 9,
                                max: 24,
                                divisions: 15,
                                value: s.terminalFontSize.clamp(9, 24).toDouble(),
                                label: s.terminalFontSize.round().toString(),
                                onChanged: ctrl.setTerminalFontSize,
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: Text('${s.terminalFontSize.round()}',
                                  textAlign: TextAlign.end),
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
                        'root@server:~\$ htop   # font preview',
                        style: monoStyle(context,
                            size: s.terminalFontSize, color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.content_copy),
                      title: Text(strings.copyOnSelectTitle),
                      subtitle: Text(DesktopEnv.isDesktop
                          ? strings.copyOnSelectDesktopDesc
                          : strings.copyOnSelectMobileDesc),
                      value: s.copyOnSelect,
                      onChanged: ctrl.setCopyOnSelect,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.keyboard_outlined),
                      title: Text(strings.accessoryBarTitle),
                      subtitle: Text(strings.accessoryBarDesc),
                      value: s.showAccessoryBar,
                      onChanged: ctrl.setShowAccessoryBar,
                    ),
                    const SizedBox(height: 8),
                    _Row(
                      title: strings.languageTitle,
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
                        onChanged: (v) => v != null ? ctrl.setLanguage(v) : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      DesktopEnv.isMobile ? strings.rightClickMobileTitle : strings.rightClickDesktopTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<RightClickAction>(
                      segments: [
                        ButtonSegment(
                            value: RightClickAction.menu,
                            icon: const Icon(Icons.menu_open),
                            label: Text(strings.rightClickMenu)),
                        ButtonSegment(
                            value: RightClickAction.paste,
                            icon: const Icon(Icons.content_paste),
                            label: Text(strings.rightClickPaste)),
                        ButtonSegment(
                            value: RightClickAction.smart,
                            icon: const Icon(Icons.auto_awesome),
                            label: Text(strings.rightClickSmart)),
                      ],
                      selected: {s.rightClick},
                      onSelectionChanged: (v) => ctrl.setRightClick(v.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DesktopEnv.isDesktop
                          ? '${_rightClickHint(s.rightClick, strings)} ${strings.shiftRightClickNote}'
                          : _rightClickHint(s.rightClick, strings),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (DesktopEnv.isDesktop) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.keyboard),
                        title: Text(strings.ctrlVPasteTitle),
                        subtitle: Text(strings.ctrlVPasteDesc),
                        value: s.ctrlVPaste,
                        onChanged: ctrl.setCtrlVPaste,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.mouse_outlined),
                        title: Text(strings.isRu ? 'Средняя кнопка мыши вставляет' : 'Middle click pastes'),
                        subtitle: Text(strings.isRu ? 'Как в Linux' : 'Linux terminal style'),
                        value: s.middleClickPaste,
                        onChanged: ctrl.setMiddleClickPaste,
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.warning_amber_rounded),
                      title: Text(strings.multilinePasteTitle),
                      subtitle: Text(strings.multilinePasteDesc),
                      value: s.confirmMultilinePaste,
                      onChanged: ctrl.setConfirmMultilinePaste,
                    ),
                  ],
                ),
                _Section(
                  icon: Icons.folder_outlined,
                  title: strings.isRu ? 'Данные' : 'Data',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.downloadsDirTitle),
                      subtitle: Text(
                          s.downloadsDir.isEmpty
                              ? '${LocalFiles.defaultDownloadsDir()} (${strings.isRu ? 'по умолчанию' : 'default'})'
                              : s.downloadsDir,
                          style: monoStyle(context, size: 12, color: scheme.onSurfaceVariant)),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (s.downloadsDir.isNotEmpty)
                            IconButton(
                              tooltip: strings.resetDefault,
                              icon: const Icon(Icons.restart_alt),
                              onPressed: () => ctrl.setDownloadsDir(''),
                            ),
                          IconButton(
                            tooltip: strings.chooseFolder,
                            icon: const Icon(Icons.folder_open),
                            onPressed: () async {
                              final dir = await getDirectoryPath();
                              if (dir != null) ctrl.setDownloadsDir(dir);
                            },
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.isRu ? 'Папка с данными' : 'Config folder'),
                      subtitle: Text(AppPaths.configDir.path,
                          style: monoStyle(context, size: 12, color: scheme.onSurfaceVariant)),
                      trailing: IconButton(
                        tooltip: strings.isRu ? 'Скопировать путь' : 'Copy path',
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: AppPaths.configDir.path));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.isRu ? 'Путь скопирован' : 'Path copied')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _Section(
                  icon: Icons.info_outline,
                  title: strings.aboutApp,
                  children: [
                    Text('vysh $appVersion', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(strings.appDescription,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
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
  const _Section({required this.icon, required this.title, required this.children});

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

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        SizedBox(width: 140, child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        child,
      ],
    );
  }
}

String _rightClickHint(RightClickAction a, AppStrings strings) => switch (a) {
      RightClickAction.menu => strings.rightClickHintMenu,
      RightClickAction.paste => strings.rightClickHintPaste,
      RightClickAction.smart => strings.rightClickHintSmart,
    };
