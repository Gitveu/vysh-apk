import 'dart:io';
import 'package:flutter/services.dart';

class MonetColors {
  const MonetColors({
    required this.accent,
    required this.accentPrimary,
    required this.background,
  });

  final Color accent;
  final Color accentPrimary;
  final Color background;
}

abstract final class AppIconManager {
  static const _channel = MethodChannel('com.vysh.vysh/app_icon');

  static Future<MonetColors?> getMonetColors() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getMonetColors');
      if (res != null) {
        final accent = (res['accent'] as num?)?.toInt();
        final accentPrimary = (res['accentPrimary'] as num?)?.toInt();
        final bg = (res['background'] as num?)?.toInt();
        if (accent != null && bg != null) {
          return MonetColors(
            accent: Color(accent),
            accentPrimary: Color(accentPrimary ?? accent),
            background: Color(bg),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> setIcon(String icon) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setIcon', {'icon': icon});
    } catch (_) {}
  }
}
