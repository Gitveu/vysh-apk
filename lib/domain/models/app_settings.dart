import 'package:flutter/material.dart';

/// Что делает правый клик (и тап двумя пальцами по тачпаду) в терминале.
enum RightClickAction {
  /// Контекстное меню.
  menu,

  /// Вставка из буфера (как в PuTTY).
  paste,

  /// Есть выделение — копировать, нет — вставить (как в Windows Terminal).
  smart,
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF6750A4,
    this.compact = false,
    this.terminalFontSize = 14,
    this.copyOnSelect = false,
    this.downloadsDir = '',
    this.pingHosts = true,
    this.rightClick = RightClickAction.menu,
    this.middleClickPaste = false,
    this.ctrlVPaste = false,
    this.confirmMultilinePaste = true,
  });

  final ThemeMode themeMode;
  final int seedColor;
  final bool compact;
  final double terminalFontSize;
  final bool copyOnSelect;

  /// Папка для скачанных файлов; пусто — системная «Загрузки».
  final String downloadsDir;

  /// Проверять доступность хостов на главной (TCP к порту SSH раз в 30 с).
  final bool pingHosts;

  final RightClickAction rightClick;

  /// Вставка средней кнопкой мыши (как в Linux).
  final bool middleClickPaste;

  /// Ctrl+V вставляет (по умолчанию Ctrl+V уходит в терминал как есть).
  final bool ctrlVPaste;

  /// Спрашивать перед вставкой нескольких строк.
  final bool confirmMultilinePaste;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedColor,
    bool? compact,
    double? terminalFontSize,
    bool? copyOnSelect,
    String? downloadsDir,
    bool? pingHosts,
    RightClickAction? rightClick,
    bool? middleClickPaste,
    bool? ctrlVPaste,
    bool? confirmMultilinePaste,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
        compact: compact ?? this.compact,
        terminalFontSize: terminalFontSize ?? this.terminalFontSize,
        copyOnSelect: copyOnSelect ?? this.copyOnSelect,
        downloadsDir: downloadsDir ?? this.downloadsDir,
        pingHosts: pingHosts ?? this.pingHosts,
        rightClick: rightClick ?? this.rightClick,
        middleClickPaste: middleClickPaste ?? this.middleClickPaste,
        ctrlVPaste: ctrlVPaste ?? this.ctrlVPaste,
        confirmMultilinePaste: confirmMultilinePaste ?? this.confirmMultilinePaste,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'seedColor': seedColor,
        'compact': compact,
        'terminalFontSize': terminalFontSize,
        'copyOnSelect': copyOnSelect,
        'downloadsDir': downloadsDir,
        'pingHosts': pingHosts,
        'rightClick': rightClick.name,
        'middleClickPaste': middleClickPaste,
        'ctrlVPaste': ctrlVPaste,
        'confirmMultilinePaste': confirmMultilinePaste,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        seedColor: (json['seedColor'] as num?)?.toInt() ?? 0xFF6750A4,
        compact: json['compact'] as bool? ?? false,
        terminalFontSize:
            ((json['terminalFontSize'] as num?)?.toDouble() ?? 14).clamp(8, 32).toDouble(),
        copyOnSelect: json['copyOnSelect'] as bool? ?? false,
        downloadsDir: json['downloadsDir'] as String? ?? '',
        pingHosts: json['pingHosts'] as bool? ?? true,
        rightClick: RightClickAction.values.firstWhere(
          (a) => a.name == json['rightClick'],
          orElse: () => RightClickAction.menu,
        ),
        middleClickPaste: json['middleClickPaste'] as bool? ?? false,
        ctrlVPaste: json['ctrlVPaste'] as bool? ?? false,
        confirmMultilinePaste: json['confirmMultilinePaste'] as bool? ?? true,
      );
}
