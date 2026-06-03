package com.virtualt.intellitaxi

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registra el canal `com.virtualt.intellitaxi/app` en cada motor Flutter
 * (principal, overlay y, si el embedding lo permite, isolate FCM).
 */
class AppForegroundPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MainActivity.registerAppChannel(
            binding.applicationContext,
            binding.binaryMessenger,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Handlers se reemplazan al adjuntar otro motor.
    }
}
