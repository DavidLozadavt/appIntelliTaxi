import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/core/services/voice_alert_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/widgets/map_dot_marker_factory.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/data/conductor_oferta_exclusiva.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/services/conductor_servicio_map_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_pasajero_helper.dart';
import 'package:intellitaxi/features/conductor/utils/oferta_exclusiva_display.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_nota_recogida_ia.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:provider/provider.dart';

/// Pantalla casi completa: oferta exclusiva inDrive (mapa + panel estilo Uber).
class ConductorOfertaExclusivaScreen extends StatefulWidget {
  const ConductorOfertaExclusivaScreen({
    super.key,
    required this.oferta,
  });

  final ConductorOfertaExclusiva oferta;

  @override
  State<ConductorOfertaExclusivaScreen> createState() =>
      _ConductorOfertaExclusivaScreenState();
}

class _ConductorOfertaExclusivaScreenState
    extends State<ConductorOfertaExclusivaScreen> {
  bool _procesando = false;
  bool _vozDireccionHecha = false;

  GoogleMapController? _mapController;
  final _mapService = ConductorServicioMapService();
  BitmapDescriptor? _iconRecogida;
  BitmapDescriptor? _iconDestino;
  BitmapDescriptor? _iconConductor;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _ultimaCamaraObjetivo;
  bool _mapaInicializado = false;
  String? _ultimaSyncMapaKey;
  String? _ultimaRutaKey;
  Timer? _timeoutCargandoDireccion;
  bool _finCargandoDireccionForzado = false;

  int _ttlTotal(ConductorHomeProvider home) {
    final delProvider = home.ofertaExclusivaTtlInicial;
    if (delProvider > 0) return delProvider;
    return widget.oferta.ttlSegundos ??
        widget.oferta.segundosRestantes ??
        45;
  }

  @override
  void initState() {
    super.initState();
    _timeoutCargandoDireccion = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _finCargandoDireccionForzado = true);
    });
    final inicial = widget.oferta.toSolicitudMap();
    if (!ConductorServicioPasajeroHelper.esGestionadoPorIa(inicial) &&
        SolicitudDisplayHelper.origenTieneMapa(inicial)) {
      unawaited(_prepararMapa());
    }
  }

  @override
  void dispose() {
    _timeoutCargandoDireccion?.cancel();
    unawaited(VoiceAlertService.stop());
    super.dispose();
  }

  bool _estaCargandoDireccion(Map<String, dynamic> solicitud) {
    if (_finCargandoDireccionForzado) return false;
    return OfertaExclusivaDisplay.mostrarCargandoDireccion(solicitud);
  }

  /// Una sola vez al llegar la oferta, cuando ya hay dirección (sin “nuevo servicio” ni extras).
  void _anunciarDireccionVoz(OfertaUbicacionVista recogida, bool cargando) {
    if (_vozDireccionHecha || cargando || !recogida.tieneDireccionLegible) {
      return;
    }
    final texto = OfertaExclusivaDisplay.textoParaVoz(recogida);
    if (texto.isEmpty) return;
    _vozDireccionHecha = true;
    unawaited(VoiceAlertService.speakSoloDireccion(texto));
  }

  String _claveSyncMapa(ConductorHomeProvider home, Map<String, dynamic> solicitud) {
    final o = _latLngOrigen(solicitud);
    final d = _latLngDestino(solicitud);
    final c = _latLngConductor(home);
    String p(LatLng? l) => l == null ? '-' : '${l.latitude},${l.longitude}';
    return '${p(o)}|${p(d)}|${p(c)}';
  }

  Future<void> _prepararMapa() async {
    _iconRecogida = await MapDotMarkerFactory.create(
      color: AppColors.green,
      size: 34,
    );
    _iconDestino = await MapDotMarkerFactory.create(
      color: const Color(0xFFFF5252),
      size: 30,
    );
    _iconConductor = await MapDotMarkerFactory.create(
      color: const Color(0xFF42A5F5),
      size: 28,
    );
    if (mounted) {
      await _sincronizarMapa(context.read<ConductorHomeProvider>());
    }
  }

  Map<String, dynamic> _datosSolicitud(ConductorHomeProvider home) {
    final sid = widget.oferta.solicitudId;
    final enriched = home.buscarSolicitudPorId(sid);
    if (enriched != null && enriched.isNotEmpty) {
      return enriched;
    }
    return widget.oferta.toSolicitudMap();
  }

  LatLng? _latLngOrigen(Map<String, dynamic> solicitud) {
    if (!SolicitudDisplayHelper.origenTieneMapa(solicitud)) return null;
    final lat = SolicitudDisplayHelper.parseCoordinate(
          solicitud['origen_lat'] ?? widget.oferta.origenLat,
        ) ??
        widget.oferta.origenLat;
    final lng = SolicitudDisplayHelper.parseCoordinate(
          solicitud['origen_lng'] ?? widget.oferta.origenLng,
        ) ??
        widget.oferta.origenLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _latLngDestino(Map<String, dynamic> solicitud) {
    final lat = SolicitudDisplayHelper.parseCoordinate(solicitud['destino_lat']);
    final lng = SolicitudDisplayHelper.parseCoordinate(solicitud['destino_lng']);
    if (lat == null || lng == null) return null;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return null;
    return LatLng(lat, lng);
  }

  LatLng? _latLngConductor(ConductorHomeProvider home) {
    final pos = home.currentPosition;
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _sincronizarMapa(ConductorHomeProvider home) async {
    final solicitud = _datosSolicitud(home);
    final recogida = _latLngOrigen(solicitud);
    final destino = _latLngDestino(solicitud);
    final conductor = _latLngConductor(home);

    final markers = <Marker>{};
    if (recogida != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('recogida'),
          position: recogida,
          icon: _iconRecogida ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    if (destino != null &&
        SolicitudDisplayHelper.hasDestination(solicitud)) {
      markers.add(
        Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          icon: _iconDestino ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    if (conductor != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: conductor,
          icon: _iconConductor ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    final objetivoCamara = recogida ?? conductor ?? destino;
    final camaraCambio = objetivoCamara != null &&
        (_ultimaCamaraObjetivo == null ||
            _ultimaCamaraObjetivo!.latitude != objetivoCamara.latitude ||
            _ultimaCamaraObjetivo!.longitude != objetivoCamara.longitude);

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _mapaInicializado = objetivoCamara != null;
    });

    if (camaraCambio) {
      _ultimaCamaraObjetivo = objetivoCamara;
      await _ajustarCamara(
        recogida: recogida,
        destino: destino,
        conductor: conductor,
      );
    }

    final rutaKey = '${conductor?.latitude},${recogida?.latitude},${destino?.latitude}';
    if (rutaKey != _ultimaRutaKey) {
      _ultimaRutaKey = rutaKey;
      if (conductor != null && recogida != null) {
        final poly = await _mapService.buildRoutePolyline(
          origin: conductor,
          destination: recogida,
          color: AppColors.brandWineLight,
        );
        if (poly != null && mounted) {
          setState(() => _polylines = {poly});
        }
      } else if (recogida != null && destino != null) {
        final poly = await _mapService.buildRoutePolyline(
          origin: recogida,
          destination: destino,
          color: AppColors.brandWineLight.withValues(alpha: 0.85),
        );
        if (poly != null && mounted) {
          setState(() => _polylines = {poly});
        }
      }
    }
  }

  Future<void> _ajustarCamara({
    required LatLng? recogida,
    required LatLng? destino,
    required LatLng? conductor,
  }) async {
    final ctrl = _mapController;
    if (ctrl == null) return;

    final puntos = <LatLng>[
      ?conductor,
      ?recogida,
      ?destino,
    ];
    if (puntos.isEmpty) return;

    try {
      if (puntos.length == 1) {
        await ctrl.animateCamera(
          CameraUpdate.newLatLngZoom(puntos.first, 15.5),
        );
        return;
      }

      var minLat = puntos.first.latitude;
      var maxLat = puntos.first.latitude;
      var minLng = puntos.first.longitude;
      var maxLng = puntos.first.longitude;
      for (final p in puntos.skip(1)) {
        minLat = minLat < p.latitude ? minLat : p.latitude;
        maxLat = maxLat > p.latitude ? maxLat : p.latitude;
        minLng = minLng < p.longitude ? minLng : p.longitude;
        maxLng = maxLng > p.longitude ? maxLng : p.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 72),
      );
    } catch (_) {
      await ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(puntos.first, 14),
      );
    }
  }

  Future<void> _rechazar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    final home = context.read<ConductorHomeProvider>();
    final ok = await home.rechazarOfertaExclusiva();
    if (!mounted) return;
    setState(() => _procesando = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo rechazar. Intenta de nuevo.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _aceptar() async {
    if (_procesando) return;
    setState(() => _procesando = true);

    final home = context.read<ConductorHomeProvider>();
    final vehiculoId = home.vehiculoSeleccionado?.id ?? 0;
    final response = await home.aceptarOfertaExclusiva(vehiculoId: vehiculoId);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            home.lastAcceptError ?? 'No se pudo aceptar el servicio',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    final auth = context.read<AuthProvider>();
    final conductorId = auth.user?.id ?? 0;
    final servicio = response['servicio'];
    if (servicio is Map && mounted) {
      final normalizado = ServicioPayloadAdapter.normalize(
        servicio: Map<String, dynamic>.from(servicio),
        pasajero: response['pasajero'] is Map
            ? Map<String, dynamic>.from(response['pasajero'] as Map)
            : null,
        conductor: response['conductor'] is Map
            ? Map<String, dynamic>.from(response['conductor'] as Map)
            : null,
        vehiculo: response['vehiculo'] is Map
            ? Map<String, dynamic>.from(response['vehiculo'] as Map)
            : null,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConductorServicioActivoScreen(
            servicio: normalizado,
            conductorId: conductorId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConductorHomeProvider>(
      builder: (context, home, _) {
        final solicitud = _datosSolicitud(home);
        final recogida = OfertaExclusivaDisplay.recogida(solicitud);
        final destino = OfertaExclusivaDisplay.destino(solicitud);
        final precio = widget.oferta.precioEstimado;
        final distTexto =
            OfertaExclusivaDisplay.distanciaTexto(widget.oferta.distanciaDesdeMiKm);
        final intento = widget.oferta.intento;
        final max = widget.oferta.maxIntentos;
        final segundos = home.ofertaExclusivaSegundosRestantes;
        final ttlTotal = _ttlTotal(home);
        final urgente = segundos <= 10;
        final cargandoDireccion = _estaCargandoDireccion(solicitud);
        final tituloRecogidaFallback =
            OfertaExclusivaDisplay.tituloRecogidaFallback(solicitud);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _anunciarDireccionVoz(recogida, cargandoDireccion);
          }
        });

        if (!home.tieneOfertaExclusivaActiva) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const PopScope(
            canPop: true,
            child: Scaffold(
              backgroundColor: Color(0xFF121212),
              body: Center(
                child: Text(
                  'La oferta ya no está disponible',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          );
        }

        final esIa =
            ConductorServicioPasajeroHelper.esGestionadoPorIa(solicitud);
        final telefonoIa =
            ConductorServicioPasajeroHelper.telefonoFormateadoVisible(solicitud);
        final etiquetaIa =
            ConductorServicioPasajeroHelper.etiquetaOrigenServicio(solicitud);
        final mostrarAvisoSinMapa = OfertaExclusivaDisplay.mostrarAvisoSinMapa(
          solicitud,
          cargandoDireccion: cargandoDireccion,
        );
        final textoAvisoSinMapa =
            OfertaExclusivaDisplay.avisoSinMapaTexto(solicitud);

        if (esIa) {
          return PopScope(
            canPop: !_procesando,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: _VistaOfertaIa(
                recogida: recogida,
                destino: destino,
                precio: precio,
                segundos: segundos,
                ttlTotal: ttlTotal,
                urgente: urgente,
                procesando: _procesando,
                telefono: telefonoIa,
                etiquetaIa: etiquetaIa,
                intento: intento,
                maxIntentos: max,
                cargandoDireccion: cargandoDireccion,
                mostrarAvisoSinMapa: mostrarAvisoSinMapa,
                textoAvisoSinMapa: textoAvisoSinMapa,
                tituloRecogidaFallback: tituloRecogidaFallback,
                onRechazar: _rechazar,
                onAceptar: _aceptar,
              ),
            ),
          );
        }

        final origenMapa = _latLngOrigen(solicitud);
        final posConductor = _latLngConductor(home);
        final centroMapa = origenMapa ??
            posConductor ??
            const LatLng(2.4414, -76.6063);

        final syncKey = _claveSyncMapa(home, solicitud);
        if (syncKey != _ultimaSyncMapaKey) {
          _ultimaSyncMapaKey = syncKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_sincronizarMapa(home));
          });
        }

        return PopScope(
          canPop: !_procesando,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Column(
              children: [
                Expanded(
                  flex: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_mapaInicializado || origenMapa != null || posConductor != null)
                        StandardMap(
                          onMapCreated: (c) {
                            _mapController = c;
                            unawaited(
                              _ajustarCamara(
                                recogida: origenMapa,
                                destino: _latLngDestino(solicitud),
                                conductor: posConductor,
                              ),
                            );
                          },
                          initialPosition: centroMapa,
                          zoom: 14.5,
                          markers: _markers,
                          polylines: _polylines,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          compassEnabled: false,
                          zoomControlsEnabled: false,
                          mapPadding: const EdgeInsets.only(
                            top: 56,
                            bottom: 24,
                            left: 24,
                            right: 24,
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFF1A1A1A),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.map,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Cargando mapa…',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                                stops: const [0.0, 0.22, 0.65, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _BadgeExclusiva(),
                              const Spacer(),
                              _TimerFlotante(
                                segundos: segundos,
                                total: ttlTotal,
                                urgente: urgente,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (intento != null && max != null)
                        Positioned(
                          left: 16,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              'Intento $intento / $max',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      if (distTexto.isNotEmpty)
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF5B9BFF).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Iconsax.routing,
                                  size: 15,
                                  color: Color(0xFF8EB8FF),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  distTexto,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 48,
                  child: _PanelInferior(
                    recogida: recogida,
                    destino: destino,
                    precio: precio,
                    segundos: segundos,
                    urgente: urgente,
                    procesando: _procesando,
                    cargandoDireccion: cargandoDireccion,
                    mostrarAvisoSinMapa: mostrarAvisoSinMapa,
                    textoAvisoSinMapa: textoAvisoSinMapa,
                    tituloRecogidaFallback: tituloRecogidaFallback,
                    onRechazar: _rechazar,
                    onAceptar: _aceptar,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Oferta exclusiva sin mapa: servicios web / gestionados por IA (solo barrio y datos).
class _VistaOfertaIa extends StatelessWidget {
  const _VistaOfertaIa({
    required this.recogida,
    this.destino,
    this.precio,
    required this.segundos,
    required this.ttlTotal,
    required this.urgente,
    required this.procesando,
    required this.telefono,
    this.etiquetaIa,
    this.intento,
    this.maxIntentos,
    this.cargandoDireccion = false,
    this.mostrarAvisoSinMapa = false,
    this.textoAvisoSinMapa = '',
    required this.tituloRecogidaFallback,
    required this.onRechazar,
    required this.onAceptar,
  });

  final OfertaUbicacionVista recogida;
  final OfertaUbicacionVista? destino;
  final double? precio;
  final int segundos;
  final int ttlTotal;
  final bool urgente;
  final bool procesando;
  final String telefono;
  final String? etiquetaIa;
  final int? intento;
  final int? maxIntentos;
  final bool cargandoDireccion;
  final bool mostrarAvisoSinMapa;
  final String textoAvisoSinMapa;
  final String tituloRecogidaFallback;
  final VoidCallback onRechazar;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    final barrio = recogida.barrio?.trim() ?? '';
    final calle = recogida.titulo.trim();
    final direccion = recogida.direccionVisible;
    final tituloPrincipal = cargandoDireccion
        ? '…'
        : barrio.isNotEmpty
            ? barrio
            : (calle.isNotEmpty ? calle : tituloRecogidaFallback);
    final subtituloCalle = barrio.isNotEmpty &&
            calle.isNotEmpty &&
            calle.toLowerCase() != barrio.toLowerCase()
        ? calle
        : '';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0F24),
            Color(0xFF0D0D0D),
            Color(0xFF121212),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BadgeExclusiva(),
                  const Spacer(),
                  _TimerFlotante(
                    segundos: segundos,
                    total: ttlTotal,
                    urgente: urgente,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _BadgeGestionadoIa(
                texto: etiquetaIa ?? 'Servicio gestionado por IA',
              ),
            ),
            if (intento != null && maxIntentos != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  'Intento $intento de $maxIntentos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgente ? '¡Responde ya!' : 'Ubicación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (cargandoDireccion)
                      const _CargandoDireccionBanner()
                    else ...[
                      Text(
                        tituloPrincipal,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                    if (!cargandoDireccion && subtituloCalle.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtituloCalle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE0E0E0),
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (!cargandoDireccion && direccion.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Iconsax.location,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              direccion,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.55),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (mostrarAvisoSinMapa && textoAvisoSinMapa.isNotEmpty)
                      ConductorAvisoSinMapa(
                        mensaje: textoAvisoSinMapa,
                        onDarkBackground: true,
                        margin: const EdgeInsets.only(top: 16),
                      ),
                    if (telefono.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.call,
                              size: 20,
                              color: Colors.deepPurple.shade200,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Teléfono del cliente',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.deepPurple.shade200,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    telefono,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (destino != null && destino!.tieneContenido) ...[
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 16),
                      _BloqueDestinoIa(destino: destino!),
                    ],
                    if (precio != null && precio! > 0) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '\$${precio!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'COP estimado',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '$segundos s para aceptar o rechazar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: urgente
                            ? const Color(0xFFFF8A80)
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _BotonesOferta(
              procesando: procesando,
              onRechazar: onRechazar,
              onAceptar: onAceptar,
            ),
          ],
        ),
      ),
    );
  }
}

class _BloqueDestinoIa extends StatelessWidget {
  const _BloqueDestinoIa({required this.destino});

  final OfertaUbicacionVista destino;

  @override
  Widget build(BuildContext context) {
    final barrio = destino.barrio?.trim() ?? '';
    final titulo = destino.titulo.trim();
    final dir = destino.direccionVisible;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Iconsax.location_tick, size: 20, color: Colors.redAccent.shade200),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DESTINO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent.shade200,
                  letterSpacing: 0.8,
                ),
              ),
              if (barrio.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  barrio,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
              if (titulo.isNotEmpty &&
                  titulo.toLowerCase() != barrio.toLowerCase())
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              if (dir.isNotEmpty)
                Text(
                  dir,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeExclusiva extends StatelessWidget {
  const _BadgeExclusiva();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandWineLight, AppColors.brandWine],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWine.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.flash_1, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Oferta exclusiva',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeGestionadoIa extends StatelessWidget {
  const _BadgeGestionadoIa({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurple.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.cpu,
            size: 18,
            color: Colors.deepPurple.shade200,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.deepPurple.shade100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonesOferta extends StatelessWidget {
  const _BotonesOferta({
    required this.procesando,
    required this.onRechazar,
    required this.onAceptar,
  });

  final bool procesando;
  final VoidCallback onRechazar;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: procesando ? null : onRechazar,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B6B),
                side: BorderSide(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.7),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Rechazar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D95A), Color(0xFF00A844)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C535).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: procesando ? null : onAceptar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: procesando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.tick_circle, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Aceptar',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerFlotante extends StatelessWidget {
  const _TimerFlotante({
    required this.segundos,
    required this.total,
    required this.urgente,
  });

  final int segundos;
  final int total;
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    final t = total > 0 ? (segundos / total).clamp(0.0, 1.0) : 0.0;
    final color = urgente ? const Color(0xFFFF5252) : Colors.white;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: t,
              strokeWidth: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$segundos',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                'seg',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelInferior extends StatelessWidget {
  const _PanelInferior({
    required this.recogida,
    this.destino,
    this.precio,
    required this.segundos,
    required this.urgente,
    required this.procesando,
    this.cargandoDireccion = false,
    this.mostrarAvisoSinMapa = false,
    this.textoAvisoSinMapa = '',
    required this.tituloRecogidaFallback,
    required this.onRechazar,
    required this.onAceptar,
  });

  final OfertaUbicacionVista recogida;
  final OfertaUbicacionVista? destino;
  final double? precio;
  final int segundos;
  final bool urgente;
  final bool procesando;
  final bool cargandoDireccion;
  final bool mostrarAvisoSinMapa;
  final String textoAvisoSinMapa;
  final String tituloRecogidaFallback;
  final VoidCallback onRechazar;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          urgente ? '¡Responde ya!' : 'Nueva solicitud',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$segundos s para aceptar o rechazar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: urgente
                                ? const Color(0xFFFF8A80)
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (precio != null && precio! > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${precio!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'COP est.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaRuta(
                      recogida: recogida,
                      destino: destino,
                      cargandoDireccion: cargandoDireccion,
                      tituloRecogidaFallback: tituloRecogidaFallback,
                    ),
                    if (mostrarAvisoSinMapa && textoAvisoSinMapa.isNotEmpty)
                      ConductorAvisoSinMapa(
                        mensaje: textoAvisoSinMapa,
                        onDarkBackground: true,
                        margin: const EdgeInsets.only(top: 12),
                      ),
                  ],
                ),
              ),
            ),
            _BotonesOferta(
              procesando: procesando,
              onRechazar: onRechazar,
              onAceptar: onAceptar,
            ),
          ],
        ),
      ),
    );
  }
}

class _CargandoDireccionBanner extends StatelessWidget {
  const _CargandoDireccionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.brandWineLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cargando dirección…',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Obteniendo barrio y calle',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({
    required this.recogida,
    this.destino,
    this.cargandoDireccion = false,
    required this.tituloRecogidaFallback,
  });

  final OfertaUbicacionVista recogida;
  final OfertaUbicacionVista? destino;
  final bool cargandoDireccion;
  final String tituloRecogidaFallback;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              if (cargandoDireccion)
                const _CargandoDireccionBanner()
              else
                _ParadaRuta(
                  color: AppColors.green,
                  icon: Iconsax.location,
                  vista: recogida,
                  tituloFallback: tituloRecogidaFallback,
                ),
              if (destino != null && destino!.tieneContenido) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.white12,
                  ),
                ),
                _ParadaRuta(
                  color: Colors.redAccent,
                  icon: Iconsax.location_tick,
                  vista: destino!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ParadaRuta extends StatelessWidget {
  const _ParadaRuta({
    required this.color,
    required this.icon,
    required this.vista,
    this.tituloFallback = '',
  });

  final Color color;
  final IconData icon;
  final OfertaUbicacionVista vista;
  final String tituloFallback;

  @override
  Widget build(BuildContext context) {
    var titulo = vista.titulo.trim();
    if (titulo.isEmpty && tituloFallback.isNotEmpty) {
      titulo = tituloFallback;
    }
    final barrio = vista.barrio?.trim() ?? '';
    final direccion = vista.direccionVisible;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (barrio.isNotEmpty)
                Text(
                  barrio,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              if (titulo.isNotEmpty &&
                  titulo.toLowerCase() != barrio.toLowerCase())
                Padding(
                  padding: EdgeInsets.only(top: barrio.isNotEmpty ? 4 : 0),
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                )
              else if (barrio.isEmpty && titulo.isNotEmpty)
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              if (direccion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    direccion,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.3,
                    ),
                  ),
                ),
              if (titulo.isEmpty && barrio.isEmpty && direccion.isEmpty)
                Text(
                  'Ubicación en el mapa',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
