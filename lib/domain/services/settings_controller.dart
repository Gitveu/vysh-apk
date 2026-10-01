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

  void _update(AppSettings next) {
    state = next;
    _store.write(next.toJson());
  }
}
