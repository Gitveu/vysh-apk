import 'dart:io';
import 'package:flutter/services.dart';

abstract final class AppIconManager {
  static const _channel = MethodChannel('com.vysh.vysh/app_icon');

  static Future<void> setIcon(String icon) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setIcon', {'icon': icon});
    } catch (_) {}
  }
}
