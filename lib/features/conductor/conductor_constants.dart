/// TTL overlay solo si el API no envía `countdown_segundos` / `overlay_expira_en`.
const int kOportunidadConductorSegundos = 120;

/// Respaldo con Pusher activo y cola vacía (si el backend no notifica privado, el API alinea).
const int kPollSolicitudesPendientesConSocketVacioSegundos = 30;

/// Respaldo con Pusher activo y cola con ítems (alinear fases / tomadas por otros).
const int kPollSolicitudesPendientesConSocketColaSegundos = 60;

/// Sin socket: polling principal hasta reconectar.
const int kPollSolicitudesPendientesSinSocketSegundos = 45;

/// Debounce antes de sync tras evento realtime (el payload ya actualizó la UI).
const int kSyncSolicitudesTrasEventoSegundos = 8;

/// Sync inicial tras conectar Pusher (evita ráfaga con arranque / turno).
const int kSyncSolicitudesTrasConexionSocketSegundos = 5;

/// Tras actualizar ubicación en mapa: alinear cola si Pusher no entregó el evento.
const int kSyncSolicitudesTrasHeartbeatSegundos = 4;

/// Poll `GET /taxi/oferta-activa` con pantalla exclusiva abierta (10–15 s recomendado).
const int kPollOfertaActivaPantallaSegundos = 12;

/// Poll de respaldo cuando hay oferta activa pero la pantalla está cerrada.
const int kPollOfertaActivaFondoSegundos = 45;

/// Tras Pusher/FCM, no quitar del mapa por sync API hasta este margen (evita sonido sin tarjeta).
const int kConservarRealtimeTrasSyncSegundos = 180;

/// Tras exclusiva→«Llegando»: fallback local si aún no llegó meta API (`oferta_exclusiva_segundos`).
const int kMantenerLlegandoTrasExclusivaSegundos = 25;

/// Reservado (dedupe de beep vive en [IncomingServiceAlertService], 6 s por id).
const int kSonidoSolicitudDedupeSegundos = 6;
