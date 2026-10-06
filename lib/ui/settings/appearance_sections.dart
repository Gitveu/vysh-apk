import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_strings.dart';
import '../../domain/models/external_colors.dart';
import '../../domain/services/external_colors_controller.dart';
import '../../domain/services/settings_controller.dart';
import '../../infra/platform/desktop_env.dart';
import '../../infra/platform/local_files.dart';
import '../theme/app_theme.dart';
import 'setting_row.dart';

const _themesDocUrl = 'https://github.com/vyto4ka/vysh/blob/main/docs/THEMES.md';

const seedPresets = [
  ('Фиолетовый', 0xFF6750A4),
  ('Синий', 0xFF1976D2),
  ('Бирюзовый', 0xFF00796B),
  ('Зелёный', 0xFF388E3C),
  ('Янтарный', 0xFFF57C00),
  ('Коралловый', 0xFFE64A19),
  ('Бордовый', 0xFFC2185B),
  ('Индиго', 0xFF303F9F),
];

/// «Откуда брать цвета»: свой акцент, системный, доты.
class ColorSourceSection extends ConsumerStatefulWidget {
  const ColorSourceSection({super.key});

  @override
  ConsumerState<ColorSourceSection> createState() => _ColorSourceSectionState();
}

class _ColorSourceSectionState extends ConsumerState<ColorSourceSection> {
  late final TextEditingController _path;

  @override
  void initState() {
    super.initState();
    _path = TextEditingController(text: ref.read(settingsProvider).dotsPath);
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final ext = ref.watch(externalColorsProvider);
    final notFound = ref.read(externalColorsProvider.notifier).notFound;
    final strings = AppStrings.of(context, s.language);
    final scheme = Theme.of(context).colorScheme;
    final error = TextStyle(color: scheme.error, fontSize: 13);

    final details = switch (s.colorSource) {
      ColorSource.preset => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (name, color) in seedPresets)
              _SeedSwatch(
                name: name,
                color: Color(color),
                selected: s.seedColor == color,
                onTap: () => ctrl.setSeedColor(color),
              ),
          ],
        ),
      ColorSource.system => ext == null && notFound
          ? Text(
              !kIsWeb && Platform.isWindows
                  ? (strings.isRu ? 'Акцент Windows не найден' : 'Windows accent not found')
                  : (strings.isRu
                      ? 'Акцент не найден: нужен xdg-desktop-portal с accent-color'
                      : 'Accent not found: requires xdg-desktop-portal with accent-color'),
              style: error,
            )
          : const SizedBox.shrink(),
      ColorSource.dots => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ext != null && ext.path != null)
              Text(
                '${ext.source}: ${ext.path}',
                style: monoStyle(context, size: 12, color: scheme.onSurfaceVariant),
              )
            else if (notFound)
              Text(
                strings.isRu ? 'Файл цветов не найден' : 'Color file not found',
                style: error,
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _path,
              style: monoStyle(context, size: 13),
              decoration: InputDecoration(
                labelText: strings.isRu ? 'Свой путь к файлу' : 'Custom file path',
                hintText: '~/.config/vysh/colors.json',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  tooltip: strings.isRu ? 'Применить' : 'Apply',
                  icon: const Icon(Icons.check),
                  onPressed: () => ctrl.setDotsPath(_path.text.trim()),
                ),
              ),
              onSubmitted: (v) => ctrl.setDotsPath(v.trim()),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => LocalFiles.openWithSystem(_themesDocUrl),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('matugen, wallust, pywal, caelestia'),
              ),
            ),
          ],
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          label: strings.colorSourceTitle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ColorSource>(
                  segments: [
                    ButtonSegment(
                      value: ColorSource.preset,
                      icon: const Icon(Icons.palette_outlined),
                      label: Text(strings.colorSourcePreset),
                    ),
                    if (!kIsWeb && (Platform.isWindows || Platform.isLinux))
                      ButtonSegment(
                        value: ColorSource.system,
                        icon: const Icon(Icons.computer),
                        label: Text(
                          !kIsWeb && Platform.isWindows
                              ? strings.colorSourceSystemWin
                              : strings.colorSourceSystemSys,
                        ),
                      ),
                    if (!kIsWeb && Platform.isLinux)
                      ButtonSegment(
                        value: ColorSource.dots,
                        icon: const Icon(Icons.wallpaper),
                        label: Text(strings.colorSourceDots),
                      ),
                  ],
                  selected: {s.colorSource},
                  onSelectionChanged: (v) => ctrl.setColorSource(v.first),
                ),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: details,
                ),
                if (s.colorSource != ColorSource.preset && ext != null) ...[
                  const SizedBox(height: 8),
                  _Preview(ext: ext, scheme: scheme),
                ],
              ],
            ),
          ),
        ),
        if (s.colorSource != ColorSource.preset && !DesktopEnv.isMobile)
          SettingRow(
            label: strings.isRu ? 'Проверка цветов' : 'Color polling',
            child: SettingChoice<int>(
              value: s.colorPollSec,
              options: [
                (0, strings.isRu ? 'Выкл.' : 'Off'),
                (10, strings.isRu ? '10 с' : '10s'),
                (60, strings.isRu ? '1 мин' : '1 min'),
                (300, strings.isRu ? '5 мин' : '5 min'),
              ],
              onChanged: ctrl.setColorPollSec,
            ),
          ),
      ],
    );
  }
}

/// Предпросмотр: акцент и 16 цветов терминала из источника.
class _Preview extends StatelessWidget {
  const _Preview({required this.ext, required this.scheme});

  final ExternalColors ext;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, [double size = 22]) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        dot(ext.seed, 30),
        const SizedBox(width: 8),
        dot(scheme.primary),
        dot(scheme.secondary),
        dot(scheme.tertiary),
        dot(scheme.primaryContainer),
        if (ext.ansi != null) ...[
          const SizedBox(width: 12),
          for (final c in ext.ansi!) dot(c, 16),
        ],
      ],
    );
  }
}

/// «Заголовок окна»: свой с вкладками или системный.
class TitleBarSection extends ConsumerWidget {
  const TitleBarSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (DesktopEnv.isMobile) return const SizedBox.shrink();
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final strings = AppStrings.of(context, s.language);
    // «Авто» в интерфейсе не показываем: пока пользователь не выбрал сам,
    // отмечен тот вариант, который сейчас действует.
    final custom = DesktopEnv.useCustomTitleBar(s.titleBarMode);
    return SettingRow(
      label: strings.titleBarTitle,
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.tab_outlined),
            label: Text(strings.titleBarCustom),
          ),
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.web_asset),
            label: Text(strings.titleBarSystem),
          ),
        ],
        selected: {custom},
        onSelectionChanged: (v) =>
            ctrl.setTitleBarMode(v.first ? TitleBarMode.custom : TitleBarMode.system),
      ),
    );
  }
}

class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Theme.of(context).brightness,
    );
    final outline = Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? outline : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Expanded(child: Container(color: scheme.primary)),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: Container(color: scheme.secondaryContainer)),
                      Expanded(child: Container(color: scheme.tertiaryContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
