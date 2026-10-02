package com.vysh.vysh

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.vysh.vysh/wakelock"
    private val iconChannelName = "com.vysh.vysh/app_icon"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        val title = call.argument<String>("title") ?: "SSH подключен"
                        if (wakeLock == null) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            wakeLock = powerManager.newWakeLock(
                                PowerManager.PARTIAL_WAKE_LOCK,
                                "vysh:ssh_session"
                            ).apply { setReferenceCounted(false) }
                        }
                        wakeLock?.acquire(60 * 60 * 1000L) // 1 hour max
                        SshForegroundService.start(this, title)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }
                "release" -> {
                    try {
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        SshForegroundService.stop(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    try {
                        val icon = call.argument<String>("icon") ?: "default"
                        val pm = packageManager
                        val defaultAlias = ComponentName(packageName, "$packageName.MainActivityDefault")
                        val monetAlias = ComponentName(packageName, "$packageName.MainActivityMonet")

                        if (icon == "monet") {
                            pm.setComponentEnabledSetting(
                                monetAlias,
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                PackageManager.DONT_KILL_APP
                            )
                            pm.setComponentEnabledSetting(
                                defaultAlias,
                                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                PackageManager.DONT_KILL_APP
                            )
                        } else {
                            pm.setComponentEnabledSetting(
                                defaultAlias,
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                PackageManager.DONT_KILL_APP
                            )
                            pm.setComponentEnabledSetting(
                                monetAlias,
                                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                PackageManager.DONT_KILL_APP
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ICON_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            SshForegroundService.stop(this)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
