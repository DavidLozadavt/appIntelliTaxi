package com.virtualt.intellitaxi

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Evita que Firebase muestre varias notificaciones del sistema por el mismo servicio.
 */
class IntelliTaxiFirebaseMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (FcmIncomingDedup.shouldSkip(this, message)) return
        FcmIncomingDedup.recordShown(this, message)
        super.onMessageReceived(message)
    }
}
