import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/storage/json_store.dart';
import '../models/app_settings.dart';

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  final _store = JsonStore('settings.json');

  @override
  AppSettings build() {
    final raw = _store.readSync();
    return raw is Map<String, Object?> ? AppSettings.fromJson(raw) : const AppSettings();
  }

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));
  void setSeedColor(int color) => _update(state.copyWith(seedColor: color));
  void setCompact(bool value) => _update(state.copyWith(compact: value));
  void setTerminalFontSize(double v) =>
      _update(state.copyWith(terminalFontSize: v.clamp(8, 32).toDouble()));
  void setCopyOnSelect(bool value) => _update(state.copyWith(copyOnSelect: value));
  void setDownloadsDir(String dir) => _update(state.copyWith(downloadsDir: dir));
  void setPingHosts(bool v) => _update(state.copyWith(pingHosts: v));
  void setRightClick(RightClickAction v) => _update(state.copyWith(rightClick: v));
  void setMiddleClickPaste(bool v) => _update(state.copyWith(middleClickPaste: v));
  void setCtrlVPaste(bool v) => _update(state.copyWith(ctrlVPaste: v));
  void setConfirmMultilinePaste(bool v) => _update(state.copyWith(confirmMultilinePaste: v));
  void setColorSource(ColorSource v) => _update(state.copyWith(colorSource: v));
  void setDotsPath(String v) => _update(state.copyWith(dotsPath: v));
  void setTitleBarMode(TitleBarMode v) => _update(state.copyWith(titleBarMode: v));
  void setKeepAliveSeconds(int seconds) => _update(state.copyWith(keepAliveSeconds: seconds));
  void setAppIcon(String icon) {
    _update(state.copyWith(appIcon: icon));
  }
  void setShowAccessoryBar(bool v) => _update(state.copyWith(showAccessoryBar: v));

  void _update(AppSettings next) {
    state = next;
    _store.write(next.toJson());
  }
}
