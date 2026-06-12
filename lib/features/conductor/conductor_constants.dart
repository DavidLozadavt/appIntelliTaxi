/// `GET /taxi/solicitudes-pendientes` — límite por defecto (spec 2026-06-12 §1.2).
const int kSolicitudesPendientesLimit = 15;

/// Respaldo si el API no envía `poll_interval_segundos`.
const int kPollIntervalSegundosFallback = 5;

/// Respaldo si el API no envía `gracia_segundos`.
const int kGraciaSegundosFallback = 10;

/// TTL overlay solo si el API no envía `countdown_segundos` / `overlay_expira_en`.
const int kOportunidadConductorSegundos = 120;

/// Sync inicial tras conectar Pusher (evita ráfaga con arranque / turno).
const int kSyncSolicitudesTrasConexionSocketSegundos = 5;

/// Tras actualizar ubicación en mapa: alinear cola si Pusher no entregó el evento.
const int kSyncSolicitudesTrasHeartbeatSegundos = 4;

/// Poll `GET /taxi/oferta-activa` con pantalla exclusiva abierta (10–15 s recomendado).
const int kPollOfertaActivaPantallaSegundos = 12;

/// Poll de respaldo cuando hay oferta activa pero la pantalla está cerrada.
const int kPollOfertaActivaFondoSegundos = 45;

/// Margen corto tras Pusher/FCM antes de que el GET confirme el ítem (evita parpadeo).
const int kConservarRealtimeTrasSyncSegundos = 15;

/// Tras exclusiva→«Llegando»: fallback local si aún no llegó meta API (`oferta_exclusiva_segundos`).
const int kMantenerLlegandoTrasExclusivaSegundos = 25;

/// Reservado (dedupe de beep vive en [IncomingServiceAlertService], 6 s por id).
const int kSonidoSolicitudDedupeSegundos = 6;
