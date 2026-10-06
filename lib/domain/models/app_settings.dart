import 'package:flutter/material.dart';

import '../../infra/platform/desktop_env.dart';

/// Что делает правый клик (и тап двумя пальцами по тачпаду) в терминале.
enum RightClickAction {
  /// Контекстное меню.
  menu,

  /// Вставка из буфера (как в PuTTY).
  paste,

  /// Есть выделение - копировать, нет - вставить (как в Windows Terminal).
  smart,
}

/// Откуда брать цвета интерфейса.
enum ColorSource {
  /// Свой акцентный цвет из настроек.
  preset,

  /// Акцент системы: Windows - цвет акцента, Linux - xdg-desktop-portal.
  system,

  /// Файлы дотов: свой colors.json, caelestia, pywal (Linux).
  dots,
}

/// Движок отрисовки Flutter. Выбирается до запуска движка (windows/runner/main.cpp,
/// linux/runner/my_application.cc), поэтому меняется только после перезапуска.
enum Renderer {
  /// Экономнее по памяти; так рисовал Flutter до 3.47.
  skia,

  /// Новый движок Flutter: без подтормаживаний при первой анимации, но
  /// держит больше памяти под текстуры.
  impeller,
}

/// Движок, с которым приложение запущено (пишется в main.dart).
Renderer startupRenderer = Renderer.skia;

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
    this.rememberTerminalFontSize = true,
    this.copyOnSelect = false,
    this.pingHosts = true,
    this.rightClick = RightClickAction.menu,
    this.confirmMultilinePaste = true,
    this.colorSource = ColorSource.preset,
    this.dotsPath = '',
    this.titleBarMode = TitleBarMode.auto,
    this.keepAliveSeconds = 60,
    this.appIcon = 'monet',
    this.showAccessoryBar = true,
    this.language = AppLanguage.auto,
    this.scrollbackLines = 10000,
    this.pingIntervalSec = 30,
    this.pingOnlyVisible = true,
    this.colorPollSec = 60,
    this.pauseHiddenTabs = true,
    this.renderer = Renderer.skia,
  });

  final ThemeMode themeMode;
  final int seedColor;
  final bool compact;
  final double terminalFontSize;
  final bool rememberTerminalFontSize;
  final bool copyOnSelect;

  /// Иконка приложения (системная Monet-иконка на Android).
  final String appIcon;

  /// Показывать строку горячих клавиш терминала (Ctrl, Esc, стрелки) над клавиатурой.
  final bool showAccessoryBar;

  /// Проверять доступность хостов на главной (TCP к порту SSH раз в 30 с).
  final bool pingHosts;

  /// Интервал KeepAlive пакетов в SSH-сессиях в секундах (0 — выключен, 15, 30, 60, 120, 300).
  /// По умолчанию 60 секунд (1 минута).
  final int keepAliveSeconds;

  final RightClickAction rightClick;

  /// Спрашивать перед вставкой нескольких строк.
  final bool confirmMultilinePaste;

  final ColorSource colorSource;

  /// Свой путь к файлу цветов; пусто - искать автоматически.
  final String dotsPath;

  final TitleBarMode titleBarMode;

  /// Язык интерфейса ('auto', 'ru', 'en').
  final AppLanguage language;

  // ── Производительность ──

  /// Строк истории терминала (для новых вкладок).
  final int scrollbackLines;

  /// Как часто проверять доступность хостов, секунд.
  final int pingIntervalSec;

  /// Проверять доступность, только пока список хостов на экране.
  final bool pingOnlyVisible;

  /// Запасной опрос цветов системы/дотов, секунд; 0 - только по событиям.
  final int colorPollSec;

  /// Останавливать анимации во вкладках, которые не на экране.
  final bool pauseHiddenTabs;

  /// Движок отрисовки (применяется после перезапуска).
  final Renderer renderer;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedColor,
    bool? compact,
    double? terminalFontSize,
    bool? rememberTerminalFontSize,
    bool? copyOnSelect,
    bool? pingHosts,
    RightClickAction? rightClick,
    bool? confirmMultilinePaste,
    ColorSource? colorSource,
    String? dotsPath,
    TitleBarMode? titleBarMode,
    int? keepAliveSeconds,
    String? appIcon,
    bool? showAccessoryBar,
    AppLanguage? language,
    int? scrollbackLines,
    int? pingIntervalSec,
    bool? pingOnlyVisible,
    int? colorPollSec,
    bool? pauseHiddenTabs,
    Renderer? renderer,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
        compact: compact ?? this.compact,
        terminalFontSize: terminalFontSize ?? this.terminalFontSize,
        rememberTerminalFontSize:
            rememberTerminalFontSize ?? this.rememberTerminalFontSize,
        copyOnSelect: copyOnSelect ?? this.copyOnSelect,
        pingHosts: pingHosts ?? this.pingHosts,
        rightClick: rightClick ?? this.rightClick,
        confirmMultilinePaste:
            confirmMultilinePaste ?? this.confirmMultilinePaste,
        colorSource: colorSource ?? this.colorSource,
        dotsPath: dotsPath ?? this.dotsPath,
        titleBarMode: titleBarMode ?? this.titleBarMode,
        keepAliveSeconds: keepAliveSeconds ?? this.keepAliveSeconds,
        appIcon: appIcon ?? this.appIcon,
        showAccessoryBar: showAccessoryBar ?? this.showAccessoryBar,
        language: language ?? this.language,
        scrollbackLines: scrollbackLines ?? this.scrollbackLines,
        pingIntervalSec: pingIntervalSec ?? this.pingIntervalSec,
        pingOnlyVisible: pingOnlyVisible ?? this.pingOnlyVisible,
        colorPollSec: colorPollSec ?? this.colorPollSec,
        pauseHiddenTabs: pauseHiddenTabs ?? this.pauseHiddenTabs,
        renderer: renderer ?? this.renderer,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'seedColor': seedColor,
        'compact': compact,
        'terminalFontSize': terminalFontSize,
        'rememberTerminalFontSize': rememberTerminalFontSize,
        'copyOnSelect': copyOnSelect,
        'pingHosts': pingHosts,
        'rightClick': rightClick.name,
        'confirmMultilinePaste': confirmMultilinePaste,
        'colorSource': colorSource.name,
        'dotsPath': dotsPath,
        'titleBarMode': titleBarMode.name,
        'keepAliveSeconds': keepAliveSeconds,
        'appIcon': appIcon,
        'showAccessoryBar': showAccessoryBar,
        'language': DesktopEnv.isMobile ? 'auto' : language.name,
        'scrollbackLines': scrollbackLines,
        'pingIntervalSec': pingIntervalSec,
        'pingOnlyVisible': pingOnlyVisible,
        'colorPollSec': colorPollSec,
        'pauseHiddenTabs': pauseHiddenTabs,
        'renderer': renderer.name,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        seedColor: (json['seedColor'] as num?)?.toInt() ?? 0xFF6750A4,
        compact: json['compact'] as bool? ?? false,
        terminalFontSize: (json['rememberTerminalFontSize'] as bool? ?? true)
            ? ((json['terminalFontSize'] as num?)?.toDouble() ?? 14)
                .clamp(8, 32)
                .toDouble()
            : 14,
        rememberTerminalFontSize:
            json['rememberTerminalFontSize'] as bool? ?? true,
        copyOnSelect: json['copyOnSelect'] as bool? ?? false,
        pingHosts: json['pingHosts'] as bool? ?? true,
        rightClick: RightClickAction.values.firstWhere(
          (a) => a.name == json['rightClick'],
          orElse: () => RightClickAction.menu,
        ),
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
        appIcon: (json['appIcon'] as String?) ?? 'monet',
        showAccessoryBar: json['showAccessoryBar'] as bool? ?? true,
        language: DesktopEnv.isMobile
            ? AppLanguage.auto
            : AppLanguage.values.firstWhere(
                (l) => l.name == json['language'],
                orElse: () => AppLanguage.auto,
              ),
        scrollbackLines: ((json['scrollbackLines'] as num?)?.toInt() ?? 10000)
            .clamp(500, maxScrollback)
            .toInt(),
        pingIntervalSec: ((json['pingIntervalSec'] as num?)?.toInt() ?? 30)
            .clamp(5, 3600)
            .toInt(),
        pingOnlyVisible: json['pingOnlyVisible'] as bool? ?? true,
        colorPollSec: ((json['colorPollSec'] as num?)?.toInt() ?? 60)
            .clamp(0, 3600)
            .toInt(),
        pauseHiddenTabs: json['pauseHiddenTabs'] as bool? ?? true,
        renderer: json['renderer'] == 'impeller'
            ? Renderer.impeller
            : Renderer.skia,
      );

  /// Верхний предел истории: xterm2 сразу резервирует список на столько строк.
  static const maxScrollback = 1000000;
}
