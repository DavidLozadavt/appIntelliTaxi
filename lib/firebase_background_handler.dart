import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/utils/fcm_isolate_context.dart';
import 'package:intellitaxi/firebase_msg.dart';
import 'package:intellitaxi/firebase_options.dart';

/// Isolate de segundo plano: procesa FCM aunque la app esté cerrada o minimizada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  FcmIsolateContext.isBackgroundHandler = true;
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await handleRemoteMessageInBackground(message);
}
