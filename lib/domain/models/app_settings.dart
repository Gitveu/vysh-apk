import 'package:flutter/material.dart';

import '../../infra/platform/desktop_env.dart';

/// Что делает правый клик (и тап двумя пальцами по тачпаду) в терминале.
enum RightClickAction {
  /// Контекстное меню.
  menu,

  /// Вставка из буфера (как в PuTTY).
  paste,

  /// Есть выделение — копировать, нет — вставить (как в Windows Terminal).
  smart,
}

/// Откуда брать цвета интерфейса.
enum ColorSource {
  /// Свой акцентный цвет из настроек.
  preset,

  /// Акцент системы: Windows — цвет акцента, Linux — xdg-desktop-portal.
  system,

  /// Файлы дотов: свой colors.json, caelestia, pywal (Linux).
  dots,
}

/// Заголовок окна.
enum TitleBarMode {
  /// Свой на Windows, GNOME и KDE; системный в тайлинговых WM.
  auto,

  /// Рамку и заголовок рисует система / оконный менеджер.
  system,

  /// Свой заголовок с вкладками.
  custom,
}

/// Язык интерфейса приложения.
enum AppLanguage {
  /// Автоматически по языку системы Android / ОС.
  auto,

  /// Русский язык.
  ru,

  /// English.
  en,
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
    this.colorSource = ColorSource.preset,
    this.dotsPath = '',
    this.titleBarMode = TitleBarMode.auto,
    this.keepAliveSeconds = 60,
    this.appIcon = 'default',
    this.showAccessoryBar = true,
    this.incognitoKeyboard = false,
    this.language = AppLanguage.auto,
  });

  final ThemeMode themeMode;
  final int seedColor;
  final bool compact;
  final double terminalFontSize;
  final bool copyOnSelect;
  final bool incognitoKeyboard;

  /// Выбранная иконка приложения ('default', 'monet', 'dark', 'matrix').
  final String appIcon;

  /// Показывать строку горячих клавиш терминала (Ctrl, Esc, стрелки) над клавиатурой.
  final bool showAccessoryBar;

  /// Папка для скачанных файлов; пусто — системная «Загрузки».
  final String downloadsDir;

  /// Проверять доступность хостов на главной (TCP к порту SSH раз в 30 с).
  final bool pingHosts;

  /// Интервал KeepAlive пакетов в SSH-сессиях в секундах (0 — выключен, 15, 30, 60, 120, 300).
  /// По умолчанию 60 секунд (1 минута).
  final int keepAliveSeconds;

  final RightClickAction rightClick;

  /// Вставка средней кнопкой мыши (как в Linux).
  final bool middleClickPaste;

  /// Ctrl+V вставляет (по умолчанию Ctrl+V уходит в терминал как есть).
  final bool ctrlVPaste;

  /// Спрашивать перед вставкой нескольких строк.
  final bool confirmMultilinePaste;

  final ColorSource colorSource;

  /// Свой путь к файлу цветов; пусто — искать автоматически.
  final String dotsPath;

  final TitleBarMode titleBarMode;

  /// Язык интерфейса ('auto', 'ru', 'en').
  final AppLanguage language;

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
    ColorSource? colorSource,
    String? dotsPath,
    TitleBarMode? titleBarMode,
    int? keepAliveSeconds,
    String? appIcon,
    bool? showAccessoryBar,
    bool? incognitoKeyboard,
    AppLanguage? language,
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
        colorSource: colorSource ?? this.colorSource,
        dotsPath: dotsPath ?? this.dotsPath,
        titleBarMode: titleBarMode ?? this.titleBarMode,
        keepAliveSeconds: keepAliveSeconds ?? this.keepAliveSeconds,
        appIcon: appIcon ?? this.appIcon,
        showAccessoryBar: showAccessoryBar ?? this.showAccessoryBar,
        incognitoKeyboard: incognitoKeyboard ?? this.incognitoKeyboard,
        language: language ?? this.language,
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
        'colorSource': colorSource.name,
        'dotsPath': dotsPath,
        'titleBarMode': titleBarMode.name,
        'keepAliveSeconds': keepAliveSeconds,
        'appIcon': appIcon,
        'showAccessoryBar': showAccessoryBar,
        'incognitoKeyboard': incognitoKeyboard,
        'language': DesktopEnv.isMobile ? 'auto' : language.name,
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
        colorSource: ColorSource.values.firstWhere(
          (c) => c.name == json['colorSource'],
          orElse: () => ColorSource.preset,
        ),
        dotsPath: json['dotsPath'] as String? ?? '',
        titleBarMode: TitleBarMode.values.firstWhere(
          (m) => m.name == json['titleBarMode'],
          orElse: () => TitleBarMode.auto,
        ),
        keepAliveSeconds: (json['keepAliveSeconds'] as num?)?.toInt() ?? 60,
        appIcon: json['appIcon'] as String? ?? 'default',
        showAccessoryBar: json['showAccessoryBar'] as bool? ?? true,
        incognitoKeyboard: json['incognitoKeyboard'] as bool? ?? false,
        language: DesktopEnv.isMobile
            ? AppLanguage.auto
            : AppLanguage.values.firstWhere(
                (l) => l.name == json['language'],
                orElse: () => AppLanguage.auto,
              ),
      );
}
