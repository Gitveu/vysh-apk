import 'dart:io';
import 'package:flutter/services.dart';

abstract final class AndroidWakeLock {
  static const _channel = MethodChannel('com.vysh.vysh/wakelock');

  static Future<void> acquire() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('acquire');
    } catch (_) {}
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('release');
    } catch (_) {}
  }
}
