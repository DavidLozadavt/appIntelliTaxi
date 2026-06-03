package com.virtualt.intellitaxi

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage

/**
 * Abre MainActivity al recibir FCM de nueva solicitud con la app en segundo plano,
 * sin depender del MethodChannel del isolate Dart de FCM.
 */
class IncomingServiceLaunchReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "IntelliTaxiFcmLaunch"
        private const val PREFS = "FlutterSharedPreferences"
        private const val ROLE_KEY = "flutter.active_role"

        private fun isIncomingServiceData(data: Map<String, String>): Boolean {
            val tipo = data["tipo"]?.lowercase() ?: return false
            if (tipo.contains("oferta_servicio_exclusiva")) return true
            if (tipo.contains("nueva_solicitud_servicio")) return true
            if (tipo.contains("servicio_asignado")) return true
            if (tipo.contains("nueva_solicitud") || tipo.contains("nueva-solicitud")) {
                return true
            }
            return false
        }

        private fun isTripUpdate(data: Map<String, String>): Boolean {
            val tipo = data["tipo"]?.lowercase() ?: return false
            if (tipo.contains("estado")) return true
            if (tipo.contains("ubicacion") || tipo.contains("ubicación")) return true
            return false
        }

        private fun isActiveConductor(context: Context): Boolean {
            val role = context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(ROLE_KEY, "")
                ?.uppercase()
                ?: ""
            return role == "CONDUCTOR-INTELLITAXI" ||
                role == "CONDUCTOR" ||
                role == "MOTORISTA" ||
                role == "DRIVER"
        }

        /** Misma heurística que firebase_messaging para «app en primer plano». */
        private fun isApplicationForeground(context: Context): Boolean {
            val keyguard =
                context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            if (keyguard?.isKeyguardLocked == true) return false

            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return false
            val packageName = context.packageName
            val processes = am.runningAppProcesses ?: return false
            for (info in processes) {
                if (info.importance ==
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                    info.processName == packageName
                ) {
                    return true
                }
            }
            return false
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras ?: return
        if (isApplicationForeground(context)) return

        val message = RemoteMessage(extras)
        val data = message.data
        val isIncoming = when {
            data.isNotEmpty() -> isIncomingServiceData(data) && !isTripUpdate(data)
            else -> {
                val combined = "${message.notification?.title ?: ""} " +
                    "${message.notification?.body ?: ""}".lowercase()
                combined.contains("solicitud") ||
                    combined.contains("servicio") ||
                    combined.contains("taxbel")
            }
        }
        if (!isIncoming || !isActiveConductor(context)) return

        Log.i(TAG, "FCM solicitud entrante → abrir MainActivity")
        MainActivity.launchMainActivity(context)
    }
}
