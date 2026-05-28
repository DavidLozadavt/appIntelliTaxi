/// TTL overlay por defecto (alineado con `TAXI_SOLICITUD_OVERLAY_TTL_SECONDS` en backend).
const int kOportunidadConductorSegundos = 120;

/// Tras Pusher/FCM, no quitar del mapa por sync API hasta este margen (evita sonido sin tarjeta).
const int kConservarRealtimeTrasSyncSegundos = 180;
