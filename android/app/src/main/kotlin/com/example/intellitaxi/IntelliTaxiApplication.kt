package com.virtualt.intellitaxi

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.app.Application
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * Cuando el conductor sale de la app, el motor del overlay ya existe:
 * registramos el MethodChannel para que el tap abra MainActivity.
 */
class IntelliTaxiApplication : Application() {
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        @Volatile
        private var appInstance: IntelliTaxiApplication? = null

        /** Lanzamiento nativo sin depender del isolate Dart (FCM en background). */
        @JvmStatic
        fun bringMainActivityToForeground() {
            val app = appInstance ?: return
            MainActivity.launchMainActivity(app.applicationContext)
        }
    }

    override fun onCreate() {
        super.onCreate()
        appInstance = this
        MainActivity.persistMainActivityResumedOnLaunch(this)
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityPaused(activity: Activity) {
                if (activity is MainActivity) {
                    scheduleOverlayChannelRegistration()
                }
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    private fun scheduleOverlayChannelRegistration() {
        handler.postDelayed({ registerOverlayEngineChannel() }, 400)
        handler.postDelayed({ registerOverlayEngineChannel() }, 1200)
    }

    private fun registerOverlayEngineChannel() {
        val messenger = FlutterEngineCache.getInstance()
            .get("myCachedEngine")
            ?.dartExecutor
            ?.binaryMessenger
            ?: return
        MainActivity.registerAppChannel(applicationContext, messenger)
    }
}
