/// Marca el isolate Dart que ejecuta [firebaseMessagingBackgroundHandler].
class FcmIsolateContext {
  FcmIsolateContext._();

  static bool isBackgroundHandler = false;
}
