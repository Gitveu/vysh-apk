import 'package:flutter/material.dart';

/// Предустановленные акцентные цвета (seed для Material You).
const seedPresets = <(String, int)>[
  ('Фиалка', 0xFF6750A4),
  ('Океан', 0xFF0061A4),
  ('Бирюза', 0xFF006A6A),
  ('Мята', 0xFF2E7D5B),
  ('Лайм', 0xFF5B6300),
  ('Янтарь', 0xFF8B5000),
  ('Коралл', 0xFFB3261E),
  ('Сакура', 0xFF9C4068),
  ('Графит', 0xFF5F6368),
];

/// Цвета меток хостов.
const hostColors = <int>[
  0xFF6750A4,
  0xFF0061A4,
  0xFF006A6A,
  0xFF2E7D5B,
  0xFF8B5000,
  0xFFB3261E,
  0xFF9C4068,
  0xFF5F6368,
];

ThemeData buildTheme({
  required Color seed,
  required Brightness brightness,
  bool compact = false,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      groupAlignment: -1,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Моноширинный шрифт терминала. Nerd Font будет вшит позже.
const monoFontFamily = 'Cascadia Mono';
const monoFontFallback = <String>[
  'JetBrainsMono Nerd Font',
  'JetBrains Mono',
  'Consolas',
  'DejaVu Sans Mono',
  'Liberation Mono',
  'monospace',
];

TextStyle monoStyle(BuildContext context, {double size = 13, Color? color}) =>
    TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: monoFontFallback,
      fontSize: size,
      height: 1.35,
      color: color,
    );
