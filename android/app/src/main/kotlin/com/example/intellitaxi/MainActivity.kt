package com.virtualt.intellitaxi

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val APP_CHANNEL = "com.virtualt.intellitaxi/app"
        private const val UPDATE_CHANNEL = "com.virtualt.intellitaxi/app_update"
        /** Tag del motor overlay (`flutter_overlay_window`). */
        private const val OVERLAY_ENGINE_TAG = "myCachedEngine"

        private val registeredMessengers = mutableSetOf<Int>()

        fun registerAppChannel(context: Context, messenger: BinaryMessenger) {
            val key = System.identityHashCode(messenger)
            if (!registeredMessengers.add(key)) return

            MethodChannel(messenger, APP_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToForeground" -> {
                        launchMainActivity(context.applicationContext)
                        result.success(true)
                    }
                    "ensureOverlayChannel" -> {
                        FlutterEngineCache.getInstance()
                            .get(OVERLAY_ENGINE_TAG)
                            ?.dartExecutor
                            ?.binaryMessenger
                            ?.let { overlayMessenger ->
                                registerAppChannel(context.applicationContext, overlayMessenger)
                            }
                        result.success(true)
                    }
                    "isScreenOn" -> {
                        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isInteractive)
                    }
                    "wakeForIncomingService" -> {
                        wakeForIncomingService(context)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        private fun launchMainActivity(context: Context) {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
        }

        private fun wakeForIncomingService(context: Context) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "intellitaxi:incoming_service",
            )
            try {
                wakeLock.acquire(15_000L)
            } catch (_: Exception) {
            } finally {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            }
            launchMainActivity(context)
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        applyShowWhenLockedFlags()
    }

    override fun onResume() {
        super.onResume()
        registerOverlayEngineChannelIfPresent()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        registerAppChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        registerOverlayEngineChannelIfPresent()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> handleInstallApk(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleInstallApk(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrBlank()) {
            result.error("INVALID_PATH", "No se recibió la ruta del APK.", null)
            return
        }

        val apkFile = File(filePath)
        if (!apkFile.exists()) {
            result.error("FILE_NOT_FOUND", "El APK no existe en la ruta indicada.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            openUnknownSourcesSettings()
            result.success("settings_opened")
            return
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(installIntent)
        result.success("install_started")
    }

    private fun registerOverlayEngineChannelIfPresent() {
        FlutterEngineCache.getInstance()
            .get(OVERLAY_ENGINE_TAG)
            ?.dartExecutor
            ?.binaryMessenger
            ?.let { messenger ->
                registerAppChannel(applicationContext, messenger)
            }
    }

    private fun applyShowWhenLockedFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        )
    }

    private fun openUnknownSourcesSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
    }
}
