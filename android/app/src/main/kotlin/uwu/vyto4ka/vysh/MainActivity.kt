package uwu.vyto4ka.vysh

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.os.Build
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "uwu.vyto4ka.vysh/wakelock"
    private val iconChannelName = "uwu.vyto4ka.vysh/app_icon"
    private val filesChannelName = "uwu.vyto4ka.vysh/local_files"
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    try {
                        // Файл уже скачан во временный путь - переносим его в
                        // общую Download через MediaStore. Разрешений не нужно.
                        val tempPath = call.argument<String>("tempPath") ?: ""
                        val name = call.argument<String>("name") ?: ""
                        val mimeType = call.argument<String>("mimeType")
                            ?: "application/octet-stream"
                        val uri = saveToDownloads(tempPath, name, mimeType)
                        result.success(uri?.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                }
                "revealPath" -> {
                    try {
                        // Открываем системный экран «Загрузки» - там лежат
                        // файлы из MediaStore.Downloads, и любой менеджер их видит.
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            Intent(android.app.DownloadManager.ACTION_VIEW_DOWNLOADS)
                        } else {
                            Intent(Intent.ACTION_VIEW).apply {
                                val path = call.argument<String>("path") ?: ""
                                setDataAndType(
                                    Uri.fromFile(java.io.File(path)),
                                    DocumentsContract.Document.MIME_TYPE_DIR
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("REVEAL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMonetColors" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val accent = getColor(android.R.color.system_accent1_200)
                            val accentPrimary = getColor(android.R.color.system_accent1_500)
                            val neutralDark = getColor(android.R.color.system_neutral1_900)
                            result.success(mapOf(
                                "accent" to (accent.toLong() and 0xFFFFFFFFL),
                                "accentPrimary" to (accentPrimary.toLong() and 0xFFFFFFFFL),
                                "background" to (neutralDark.toLong() and 0xFFFFFFFFL)
                            ))
                        } else {
                            result.success(null)
                        }
                    } catch (_: Exception) {
                        result.success(null)
                    }
                }
                "setIcon" -> {
                    // Monet is the only supported launcher icon. Keep the method for
                    // settings/state migration and make all calls idempotent.
                    try {
                        val monetAlias = ComponentName(packageName, "$packageName.MainActivityMonet")
                        packageManager.setComponentEnabledSetting(
                            monetAlias,
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ICON_ERROR", e.message, null)
                    }
                }
                "openLanguageSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val intent = Intent(Settings.ACTION_APP_LOCALE_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
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

    // ─── Скачивание в общую Download ────────────────────────────────

    /// Переносит скачанный во временный путь файл в общую папку Download.
    /// Android 10+: MediaStore.Downloads — разрешений не нужно, файл виден
    /// всем приложениям и в системном экране «Загрузки».
    /// Старые Android: прямой перенос в /storage/emulated/0/Download
    /// (там работают классические права WRITE_EXTERNAL_STORAGE).
    private fun saveToDownloads(tempPath: String, name: String, mimeType: String): Uri? {
        val temp = java.io.File(tempPath)
        if (!temp.exists()) throw java.io.FileNotFoundException(tempPath)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.Downloads.DISPLAY_NAME, name)
                put(android.provider.MediaStore.Downloads.MIME_TYPE, mimeType)
                // Уже занятое имя MediaStore сам переименует в «name (1).ext».
            }
            val resolver = contentResolver
            val uri = resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { out ->
                temp.inputStream().use { it.copyTo(out) }
            } ?: throw IllegalStateException("MediaStore stream failed")
            temp.delete()
            return uri
        }

        // Android 9 и ниже: классическая файловая система.
        val dir = java.io.File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path
        )
        if (!dir.exists()) dir.mkdirs()
        var target = java.io.File(dir, name)
        var i = 1
        while (target.exists()) {
            val dot = name.lastIndexOf('.')
            val base = if (dot > 0) name.substring(0, dot) else name
            val ext = if (dot > 0) name.substring(dot) else ""
            target = java.io.File(dir, "$base ($i)$ext")
            i++
        }
        temp.copyTo(target, overwrite = true)
        temp.delete()
        return Uri.fromFile(target)
    }
}
