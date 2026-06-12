package com.virtualt.intellitaxi

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Evita que Firebase muestre varias notificaciones del sistema por el mismo servicio.
 */
class IntelliTaxiFirebaseMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (!hasActiveSession()) {
            Log.i(TAG, "FCM ignorado: sesión cerrada")
            return
        }
        if (FcmIncomingDedup.shouldSkip(this, message)) return
        FcmIncomingDedup.recordShown(this, message)
        super.onMessageReceived(message)
    }

    private fun hasActiveSession(): Boolean {
        val token = getSharedPreferences(PREFS, MODE_PRIVATE)
            .getString(TOKEN_KEY, "")
            ?.trim()
            ?: ""
        return token.isNotEmpty()
    }

    companion object {
        private const val TAG = "IntelliTaxiFcmService"
        private const val PREFS = "FlutterSharedPreferences"
        private const val TOKEN_KEY = "flutter.token"
    }
}
