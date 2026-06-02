/// Errores de red/async que no deben contarse como crash fatal en Crashlytics.
bool isBenignNetworkAsyncError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('unsolicited response') ||
      (text.contains('httpexception') && text.contains('unexpected response')) ||
      (text.contains('http exception') && text.contains('unexpected response'));
}

bool isBenignNetworkAsyncStack(StackTrace? stack) {
  if (stack == null) return false;
  final trace = stack.toString();
  return trace.contains('WebSocket') ||
      trace.contains('pusher') ||
      trace.contains('Pusher') ||
      trace.contains('_CustomZone.bindCallback');
}

bool shouldSuppressBenignAsyncCrashReport({
  required Object error,
  StackTrace? stack,
}) {
  return isBenignNetworkAsyncError(error) || isBenignNetworkAsyncStack(stack);
}
