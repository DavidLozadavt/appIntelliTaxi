package com.virtualt.intellitaxi

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.util.Log
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
        const val APP_CHANNEL_NAME = "com.virtualt.intellitaxi/app"
        private const val APP_CHANNEL = APP_CHANNEL_NAME
        private const val UPDATE_CHANNEL = "com.virtualt.intellitaxi/app_update"
        private const val DIAG_TAG = "IntelliTaxiDiag"
        /** Tag del motor overlay (`flutter_overlay_window`). */
        private const val OVERLAY_ENGINE_TAG = "myCachedEngine"

        private val registeredMessengers = mutableSetOf<Int>()
        private var activityInstanceCounter = 0
        private var activityInstanceId = 0
        @Volatile
        var mainActivityResumed = false
            private set
        @Volatile
        private var currentMainActivity: MainActivity? = null

        /** MainActivity viva en memoria (puede estar en onCreate antes de onResume). */
        fun isMainActivityAlive(): Boolean {
            val activity = currentMainActivity ?: return false
            return !activity.isFinishing && !activity.isDestroyed
        }

        private fun tryMoveTaskToFront(context: Context) {
            try {
                val am = context.getSystemService(Context.ACTIVITY_SERVICE)
                    as ActivityManager
                am.appTasks
                    ?.firstOrNull { task ->
                        task.taskInfo.topActivity?.packageName ==
                            context.packageName
                    }
                    ?.moveToFront()
            } catch (_: Exception) {
            }
        }

        private fun hasMainTask(context: Context): Boolean {
            return try {
                val am = context.getSystemService(Context.ACTIVITY_SERVICE)
                    as ActivityManager
                am.appTasks?.any { task ->
                    task.taskInfo.topActivity?.packageName == context.packageName
                } == true
            } catch (_: Exception) {
                false
            }
        }
        private val nativeLifecycleLog = ArrayDeque<String>(40)

        private fun logNativeLifecycle(event: String) {
            val line = "${System.currentTimeMillis()} inst=$activityInstanceId $event"
            synchronized(nativeLifecycleLog) {
                if (nativeLifecycleLog.size >= 40) {
                    nativeLifecycleLog.removeFirst()
                }
                nativeLifecycleLog.addLast(line)
            }
            Log.i(DIAG_TAG, line)
        }

        private fun importanceLabel(importance: Int): String = when (importance) {
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "FOREGROUND"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE ->
                "FOREGROUND_SERVICE"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> "VISIBLE"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_PERCEPTIBLE -> "PERCEPTIBLE"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_CANT_SAVE_STATE ->
                "CANT_SAVE_STATE"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> "SERVICE"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_TOP_SLEEPING ->
                "TOP_SLEEPING"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_BACKGROUND -> "BACKGROUND"
            ActivityManager.RunningAppProcessInfo.IMPORTANCE_GONE -> "GONE"
            else -> "UNKNOWN($importance)"
        }

        private fun buildDiagnosticsSnapshot(context: Context): Map<String, Any> {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mem = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mem)

            var processImportance = "n/a"
            val processes = am.runningAppProcesses
            if (processes != null) {
                val pid = Process.myPid()
                processes.firstOrNull { it.pid == pid }?.let {
                    processImportance = importanceLabel(it.importance)
                }
            }

            val lifecycleLines = synchronized(nativeLifecycleLog) {
                nativeLifecycleLog.toList()
            }

            val ignoringBattery =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    pm.isIgnoringBatteryOptimizations(context.packageName)
                } else {
                    true
                }

            return mapOf(
                "pid" to Process.myPid(),
                "activityInstanceId" to activityInstanceId,
                "activityInstancesCreated" to activityInstanceCounter,
                "overlayEnginePresent" to (
                    FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_TAG) != null
                    ),
                "isScreenOn" to pm.isInteractive,
                "ignoringBatteryOptimizations" to ignoringBattery,
                "processImportance" to processImportance,
                "lowMemory" to mem.lowMemory,
                "availMemMb" to (mem.availMem / (1024 * 1024)),
                "nativeLifecycle" to lifecycleLines.joinToString("\n"),
            )
        }

        private fun openBatteryOptimizationSettings(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }

        fun registerAppChannel(context: Context, messenger: BinaryMessenger) {
            val key = System.identityHashCode(messenger)
            if (!registeredMessengers.add(key)) return

            MethodChannel(messenger, APP_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToForeground" -> {
                        logNativeLifecycle("bringToForeground")
                        launchMainActivity(context.applicationContext)
                        result.success(true)
                    }
                    "launchMainActivityDirect" -> {
                        logNativeLifecycle("launchMainActivityDirect")
                        IntelliTaxiApplication.bringMainActivityToForeground()
                        result.success(true)
                    }
                    "getDiagnosticsSnapshot" -> {
                        result.success(buildDiagnosticsSnapshot(context.applicationContext))
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings(context.applicationContext)
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
                        logNativeLifecycle("wakeForIncomingService")
                        wakeForIncomingService(context)
                        result.success(true)
                    }
                    "checkFreshInstall" -> {
                        val epoch = readFirstInstallEpochMs(context.applicationContext)
                        result.success(
                            mapOf(
                                "firstInstallMs" to epoch,
                            ),
                        )
                    }
                    "setKeepScreenOn" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        val activity = context as? MainActivity
                        activity?.runOnUiThread {
                            if (enable) {
                                activity.window.addFlags(
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                                )
                            } else {
                                activity.window.clearFlags(
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                                )
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        private const val PREFS = "FlutterSharedPreferences"
        private const val MAIN_ACTIVITY_RESUMED_KEY = "flutter.main_activity_resumed"

        private fun persistMainActivityResumed(context: Context, resumed: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(MAIN_ACTIVITY_RESUMED_KEY, resumed)
                .apply()
        }

        /** Arranque en frío: evita `main_activity_resumed` obsoleto si el proceso murió en onResume. */
        fun persistMainActivityResumedOnLaunch(context: Context) {
            persistMainActivityResumed(context, false)
        }

        /** Abre MainActivity desde Application, overlay o FCM (siempre en main thread). */
        fun launchMainActivity(context: Context) {
            val appContext = context.applicationContext
            val openMain: () -> Unit = {
                wakeForIncomingService(appContext)
                if (mainActivityResumed) {
                    logNativeLifecycle("launchMainActivity skip (resumed)")
                } else {
                    tryMoveTaskToFront(appContext)
                    val intent = Intent(appContext, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
                        }
                    }
                    try {
                        appContext.startActivity(intent)
                        logNativeLifecycle("launchMainActivity ok")
                    } catch (e: Exception) {
                        Log.w(DIAG_TAG, "launchMainActivity falló: ${e.message}")
                    }
                }
            }
            if (Looper.myLooper() == Looper.getMainLooper()) {
                openMain()
            } else {
                Handler(Looper.getMainLooper()).post(openMain)
            }
        }

        /// Solo enciende pantalla. NO reinicia la Activity (evita que la app «se cierre sola»).
        private fun wakeForIncomingService(context: Context) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            try {
                @Suppress("DEPRECATION")
                val wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "intellitaxi:incoming_wake",
                )
                wakeLock.acquire(8_000L)
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            } catch (_: Exception) {
            }
        }

        /** Epoch de instalación (cambia al reinstalar; no se restaura con backup de prefs). */
        private fun readFirstInstallEpochMs(context: Context): Long {
            val pm = context.packageManager
            val info = pm.getPackageInfo(context.packageName, 0)
            return info.firstInstallTime
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        activityInstanceId = ++activityInstanceCounter
        currentMainActivity = this
        logNativeLifecycle(
            "onCreate recreated=${savedInstanceState != null}",
        )
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        logNativeLifecycle("onStart")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        logNativeLifecycle("onNewIntent")
    }

    override fun onResume() {
        super.onResume()
        mainActivityResumed = true
        persistMainActivityResumed(this, true)
        logNativeLifecycle("onResume")
        registerOverlayEngineChannelIfPresent()
    }

    override fun onPause() {
        mainActivityResumed = false
        persistMainActivityResumed(this, false)
        logNativeLifecycle("onPause")
        super.onPause()
    }

    override fun onStop() {
        logNativeLifecycle("onStop")
        super.onStop()
    }

    override fun onDestroy() {
        logNativeLifecycle("onDestroy isFinishing=$isFinishing")
        if (currentMainActivity === this) {
            currentMainActivity = null
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.plugins.add(AppForegroundPlugin())
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
