/// TTL overlay solo si el API no envía `countdown_segundos` / `overlay_expira_en`.
const int kOportunidadConductorSegundos = 120;

/// Polling `GET /taxi/solicitudes-pendientes` (3–5 s recomendado).
const int kPollSolicitudesPendientesSegundos = 4;

/// Poll `GET /taxi/oferta-activa` con pantalla exclusiva abierta (10–15 s recomendado).
const int kPollOfertaActivaPantallaSegundos = 12;

/// Poll de respaldo cuando hay oferta activa pero la pantalla está cerrada.
const int kPollOfertaActivaFondoSegundos = 45;

/// Tras Pusher/FCM, no quitar del mapa por sync API hasta este margen (evita sonido sin tarjeta).
const int kConservarRealtimeTrasSyncSegundos = 180;

/// Tras exclusiva→«Llegando»: no mandar a «En espera» por sync/TTL local (evita ping-pong).
const int kMantenerLlegandoTrasExclusivaSegundos = 25;

/// Reservado (dedupe de beep vive en [IncomingServiceAlertService], 6 s por id).
const int kSonidoSolicitudDedupeSegundos = 6;
