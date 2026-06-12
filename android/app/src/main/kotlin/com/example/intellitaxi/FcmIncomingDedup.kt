package com.virtualt.intellitaxi

import android.content.Context
import android.util.Log
import com.google.firebase.messaging.RemoteMessage

/** Dedup FCM nativo (mismas claves que [ConductorIncomingDedupStore] en Dart). */
object FcmIncomingDedup {
    private const val TAG = "IntelliTaxiFcmDedup"
    private const val PREFS = "FlutterSharedPreferences"
    private const val REALTIME_ID = "flutter.conductor_incoming_realtime_id"
    private const val REALTIME_AT = "flutter.conductor_incoming_realtime_at_ms"
    private const val PUSH_ID = "flutter.conductor_incoming_push_id"
    private const val PUSH_AT = "flutter.conductor_incoming_push_at_ms"
    private const val TTL_MS = 90_000L
    private const val GLOBAL_THROTTLE_MS = 20_000L

    fun servicioId(data: Map<String, String>): String? {
        return data["servicio_id"]
            ?: data["servicioId"]
            ?: data["solicitud_id"]
            ?: data["id"]
    }

    fun isIncomingServiceData(data: Map<String, String>): Boolean {
        val notif = data["notificacion_tipo"]?.lowercase()?.trim() ?: ""
        if (notif == "cercano_broadcast" ||
            notif == "global_indrive" ||
            notif == "fase_abierta_indrive" ||
            notif == "exclusiva_indrive" ||
            notif == "oferta_directa"
        ) {
            return true
        }
        val tipo = data["tipo"]?.lowercase()?.trim() ?: ""
        if (tipo.contains("oferta_servicio_exclusiva")) return true
        if (tipo.contains("nueva_solicitud_servicio")) return true
        if (tipo.contains("servicio_asignado")) return true
        if (tipo.contains("nueva_solicitud") || tipo.contains("nueva-solicitud")) {
            return true
        }
        val route = data["route"]?.lowercase()?.trim() ?: ""
        if (route == "servicio" &&
            (data.containsKey("servicio_id") ||
                data.containsKey("solicitud_id") ||
                data.containsKey("id"))
        ) {
            return true
        }
        return false
    }

    fun shouldSkip(context: Context, message: RemoteMessage): Boolean {
        val data = message.data
        if (data.isEmpty() || !isIncomingServiceData(data)) return false

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val servicioId = servicioId(data)

        val lastPushAt = prefs.getLong(PUSH_AT, 0L)
        if (lastPushAt > 0 && now - lastPushAt <= GLOBAL_THROTTLE_MS) {
            val lastPushId = prefs.getString(PUSH_ID, null)
            if (servicioId == null || servicioId == lastPushId) {
                Log.i(TAG, "FCM push omitido (throttle global) id=$servicioId")
                return true
            }
        }

        if (servicioId == null) return false

        for (entry in listOf(
            REALTIME_ID to REALTIME_AT,
            PUSH_ID to PUSH_AT,
        )) {
            val lastId = prefs.getString(entry.first, null) ?: continue
            val lastAt = prefs.getLong(entry.second, 0L)
            if (lastId == servicioId && lastAt > 0 && now - lastAt <= TTL_MS) {
                Log.i(TAG, "FCM push omitido (duplicado) id=$servicioId")
                return true
            }
        }
        return false
    }

    fun recordShown(context: Context, message: RemoteMessage) {
        val data = message.data
        if (data.isEmpty() || !isIncomingServiceData(data)) return
        val servicioId = servicioId(data) ?: return
        val now = System.currentTimeMillis()
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PUSH_ID, servicioId)
            .putLong(PUSH_AT, now)
            .putString(REALTIME_ID, servicioId)
            .putLong(REALTIME_AT, now)
            .apply()
    }
}
