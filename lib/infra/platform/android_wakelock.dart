import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class AndroidWakeLock {
  static const _channel = MethodChannel('com.vysh.vysh/wakelock');

  static Future<void> acquire({String? title}) async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid) return;
      await _channel.invokeMethod<bool>('acquire', {'title': title ?? 'SSH подключен'});
    } catch (_) {}
  }

  static Future<void> release() async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid) return;
      await _channel.invokeMethod<bool>('release');
    } catch (_) {}
  }
}
