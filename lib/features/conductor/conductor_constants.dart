/// TTL overlay por defecto (alineado con `TAXI_SOLICITUD_OVERLAY_TTL_SECONDS` en backend).
const int kOportunidadConductorSegundos = 120;

/// Poll `GET /taxi/oferta-activa` con pantalla exclusiva abierta (10–15 s recomendado).
const int kPollOfertaActivaPantallaSegundos = 18;

/// Poll de respaldo cuando hay oferta activa pero la pantalla está cerrada.
const int kPollOfertaActivaFondoSegundos = 45;

/// Tras Pusher/FCM, no quitar del mapa por sync API hasta este margen (evita sonido sin tarjeta).
const int kConservarRealtimeTrasSyncSegundos = 180;

/// Evita doble sonido si la misma solicitud llega por Pusher + FCM + sync a la vez.
const int kSonidoSolicitudDedupeSegundos = 75;
