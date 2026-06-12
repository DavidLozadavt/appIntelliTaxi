package com.virtualt.intellitaxi

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
        private const val TOKEN_KEY = "flutter.token"

        private fun hasActiveSession(context: Context): Boolean {
            val token = context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(TOKEN_KEY, "")
                ?.trim()
                ?: ""
            return token.isNotEmpty()
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
    }

    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras ?: return
        // Con burbuja activa el proceso sigue FOREGROUND pero MainActivity no está visible.
        if (MainActivity.mainActivityResumed) {
            return
        }

        val message = RemoteMessage(extras)
        if (FcmIncomingDedup.shouldSkip(context, message)) return

        val data = message.data
        val isIncoming = when {
            data.isNotEmpty() -> FcmIncomingDedup.isIncomingServiceData(data) && !isTripUpdate(data)
            else -> {
                val combined = "${message.notification?.title ?: ""} " +
                    "${message.notification?.body ?: ""}".lowercase()
                combined.contains("solicitud") ||
                    combined.contains("servicio") ||
                    combined.contains("taxbel")
            }
        }
        if (!isIncoming || !hasActiveSession(context) || !isActiveConductor(context)) return

        if (MainActivity.mainActivityResumed) {
            Log.i(TAG, "FCM solicitud entrante → skip (MainActivity visible)")
            return
        }

        Log.i(TAG, "FCM solicitud entrante → abrir MainActivity")
        MainActivity.launchMainActivity(context)
    }
}
