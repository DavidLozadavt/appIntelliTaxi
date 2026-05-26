import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';
import 'package:intellitaxi/features/pasajero/services/ride_request_service.dart';
import 'package:intellitaxi/features/pasajero/services/repeat_trip_service.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/widgets/driver_offer_card.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/features/rides/services/active_service_manager.dart';
import 'package:intellitaxi/features/rides/presentation/active_service_screen.dart';
import 'package:intellitaxi/features/pasajero/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/conductor/data/conductor_model.dart';
import 'package:intellitaxi/features/conductor/services/conductores_service.dart';
import 'package:intellitaxi/features/conductor/services/pusher_conductores_service.dart';
// import 'package:intellitaxi/features/pasajero/travel_assistant/travel_assistant_screen.dart';
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/no_drivers_available_dialog.dart';
import 'package:intellitaxi/features/pasajero/widgets/service_type_selector.dart';
import 'package:intellitaxi/features/pasajero/widgets/route_info_card.dart';
import 'package:intellitaxi/features/pasajero/widgets/ride_request_floating_cta.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/services/service_navigation_helper.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';

class HomePasajero extends StatefulWidget {
  final List<dynamic> stories;

  const HomePasajero({super.key, required this.stories});

  @override
  State<HomePasajero> createState() => _HomePasajeroState();
}

enum _SheetVisualState { compact, middle, expanded }

class _HomePasajeroState extends State<HomePasajero>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Verificando tu ubicación actual con GPS de alta precisión...';

  // Para el bottom sheet con snap
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  static const double _sheetMinSize = 0.16;
  static const double _sheetMidSize = 0.52;
  static const double _sheetMaxSize = 0.88;
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_sheetMinSize);
  double _sheetSize = _sheetMinSize;
  _SheetVisualState _sheetVisualState = _SheetVisualState.compact;
  _SheetVisualState? _lastHapticSnap;

  // Para las búsquedas
  final PlacesService _placesService = PlacesService();
  final RoutesService _routesService = RoutesService();
  final RideRequestService _rideRequestService = RideRequestService();
  final ReverseGeocodingService _reverseGeocodingService =
      ReverseGeocodingService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();

  TripLocation? _selectedOrigin;
  TripLocation? _selectedDestination;
  String? _selectedDestinationArea;
  RouteInfo? _routeInfo;

  List<PlacePrediction> _originPredictions = [];
  List<PlacePrediction> _destinationPredictions = [];
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;
  bool _isSubmittingRide = false;
  bool _isDrawingRoute = false;
  Timer? _originSearchDebounce;
  Timer? _destinationSearchDebounce;
  int _originSearchRequestId = 0;
  int _destinationSearchRequestId = 0;

  // Tipo de servicio: 'taxi' o 'domicilio'
  String _serviceType = 'taxi';

  // Marcadores y polilíneas
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _userMarkerIcon;
  BitmapDescriptor? _destinationPointIcon;

  // Para contraofertas de conductores
  Map<String, dynamic>? _currentOffer;
  bool _showOffer = false;
  final bool _enableGlobalOffersChannel = false;

  // Gestor de servicio activo
  final ActiveServiceManager _activeServiceManager = ActiveServiceManager();

  // Referencia segura al ScaffoldMessenger
  ScaffoldMessengerState? _scaffoldMessenger;

  // Conductores disponibles
  final ConductoresService _conductoresService = ConductoresService();
  PusherConductoresService? _pusherConductoresService;
  final Map<int, Conductor> _conductoresDisponibles = {};
  final Map<int, LatLng> _driverDisplayedPositions = {};
  Conductor? _selectedDirectDriver;
  BitmapDescriptor? _driverMarkerIcon;
  final bool _showDrivers = true; // Toggle para mostrar/ocultar conductores
  Ticker? _driverMarkersTicker;
  Timer? _driversRefreshTimer;
  static const double _driverLerpFactor = 0.2;
  static const double _driverSnapDistanceMeters = 2.0;
  bool _isDisposed = false;
  String _currentLocationName = 'Mi ubicación';
  String _currentLocationAddress = 'Mi ubicación actual';
  bool _prefsLoaded = false;
  List<TripLocation> _recentDestinations = [];
  bool _notificationPermissionRequestedInSession = false;

  bool get _isExpanded => _sheetVisualState != _SheetVisualState.compact;

  bool get _hasOrigin => _selectedOrigin != null;

  bool get _hasDestination => _selectedDestination != null;

  bool get _hasRoute => _routeInfo != null;

  bool get _needsRouteRetry =>
      _serviceType != 'taxi' && _hasOrigin && _hasDestination && !_hasRoute;

  bool get _canRequestRide =>
      _hasOrigin &&
      (_serviceType == 'taxi' || (_hasDestination && _hasRoute));

  bool get _showFloatingRequestCta =>
      _canRequestRide ||
      _needsRouteRetry ||
      _isSubmittingRide ||
      (_isDrawingRoute && _serviceType != 'taxi');

  @override
  void initState() {
    super.initState();
    _createUserMarkerIcon();
    _createDriverMarkerIcon();
    _createDestinationPointIcon();
    _initializeLocation();
    _setupPusherOffers();
    _setupPusherRequestConfirmation();
    _checkActiveService(); // Verificar servicio activo al iniciar
    _setupPusherConductores(); // Configurar Pusher para conductores

    // Listeners
    _originController.addListener(_onOriginChanged);
    _destinationController.addListener(_onDestinationChanged);
    RepeatTripService.instance.addListener(_onRepeatTripRequested);
    _sheetController.addListener(_onSheetControllerChanged);
    _driverMarkersTicker = createTicker(_onDriverMarkersTick)..start();
  }

  void _onDriverMarkersTick(Duration elapsed) {
    if (!mounted || _isDisposed || !_showDrivers) return;
    if (_conductoresDisponibles.isEmpty) {
      if (_driverDisplayedPositions.isNotEmpty) {
        _driverDisplayedPositions.clear();
        _syncMarkersOnMap();
      }
      return;
    }

    var changed = false;

    for (final entry in _conductoresDisponibles.entries) {
      final id = entry.key;
      final target = LatLng(entry.value.lat, entry.value.lng);
      final current = _driverDisplayedPositions[id];

      if (current == null) {
        _driverDisplayedPositions[id] = target;
        changed = true;
        continue;
      }

      final movedMeters = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );

      if (movedMeters < _driverSnapDistanceMeters) {
        if (current.latitude != target.latitude ||
            current.longitude != target.longitude) {
          _driverDisplayedPositions[id] = target;
          changed = true;
        }
        continue;
      }

      final lat =
          current.latitude +
          (target.latitude - current.latitude) * _driverLerpFactor;
      final lng =
          current.longitude +
          (target.longitude - current.longitude) * _driverLerpFactor;
      _driverDisplayedPositions[id] = LatLng(lat, lng);
      changed = true;
    }

    for (final id in _driverDisplayedPositions.keys.toList()) {
      if (!_conductoresDisponibles.containsKey(id)) {
        _driverDisplayedPositions.remove(id);
        changed = true;
      }
    }

    if (changed) {
      _syncMarkersOnMap();
    }
  }

  void _seedDriverDisplayedPositions() {
    for (final entry in _conductoresDisponibles.entries) {
      final target = LatLng(entry.value.lat, entry.value.lng);
      _driverDisplayedPositions[entry.key] = target;
    }
  }

  void _startDriversRefreshTimer() {
    _driversRefreshTimer?.cancel();
    _driversRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadAvailableDrivers(silent: true),
    );
  }

  void _onSheetControllerChanged() {
    if (!_sheetController.isAttached || _isDisposed) return;
    final size = _sheetController.size;
    if ((size - _sheetExtent.value).abs() >= 0.002) {
      _sheetExtent.value = size;
    }
    if ((size - _sheetSize).abs() < 0.008) return;
    _sheetSize = size;
    final nextVisualState = _sheetStateFromExtent(size);
    if (nextVisualState == _sheetVisualState) return;
    _sheetVisualState = nextVisualState;
    _emitSnapHapticIfNeeded(size, nextVisualState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted) return;

    // Guardar referencia segura al ScaffoldMessenger
    _scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!_prefsLoaded) {
      _prefsLoaded = true;
      _loadSavedPassengerLocations();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Limpiar callbacks PRIMERO para evitar llamadas con context inválido
    _activeServiceManager.onServiceUpdated = null;
    _activeServiceManager.onServiceCompleted = null;

    // Limpiar referencia al ScaffoldMessenger
    _scaffoldMessenger = null;

    // Limpiar ActiveServiceManager
    _activeServiceManager.cleanup();

    // Desuscribirse de Pusher
    if (_enableGlobalOffersChannel) {
      PusherService.unsubscribeSecondary('ofertas-globales');
      PusherService.unregisterEventHandlerSecondary(
        'ofertas-globales:nueva-oferta',
      );
    }

    PusherService.unsubscribeSecondary('solicitudes-servicio');
    for (final eventName in const ['nueva-solicitud', 'nueva_solicitud']) {
      PusherService.unregisterEventHandlerSecondary(
        'solicitudes-servicio:$eventName',
      );
    }

    // Remover listeners de los controladores de texto ANTES de disponer
    _originController.removeListener(_onOriginChanged);
    _destinationController.removeListener(_onDestinationChanged);
    RepeatTripService.instance.removeListener(_onRepeatTripRequested);

    // Desconectar servicio de conductores
    _pusherConductoresService?.disconnect();

    _mapController?.dispose();
    _sheetController.removeListener(_onSheetControllerChanged);
    _sheetController.dispose();
    _sheetExtent.dispose();
    _driverMarkersTicker?.dispose();
    _driversRefreshTimer?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _originSearchDebounce?.cancel();
    _destinationSearchDebounce?.cancel();
    _placesService.clearAutocompleteSession();

    super.dispose();
  }

  void _setStateSafe(VoidCallback fn) {
    if (_isDisposed || !mounted) return;
    setState(fn);
  }

  void _onRepeatTripRequested() {
    _tryApplyPendingRepeatTrip();
  }

  Future<void> _tryApplyPendingRepeatTrip() async {
    if (!mounted) return;
    if (_currentPosition == null) return;

    final pending = RepeatTripService.instance.pendingTrip;
    if (pending == null) return;

    final originRaw = pending['origen'];
    final destinationRaw = pending['destino'];
    if (originRaw is! Map || destinationRaw is! Map) {
      RepeatTripService.instance.clearPending();
      return;
    }

    final origin = _tripLocationFromMap(Map<String, dynamic>.from(originRaw));
    final destination = _tripLocationFromMap(
      Map<String, dynamic>.from(destinationRaw),
    );
    if (destination == null) {
      RepeatTripService.instance.clearPending();
      return;
    }

    _setStateSafe(() {
      if (origin != null) {
        _selectedOrigin = origin;
        _originController.removeListener(_onOriginChanged);
        _originController.text = origin.name;
        _originController.addListener(_onOriginChanged);
      }
      _selectedDestination = destination;
      _selectedDestinationArea = null;
      _destinationController.text = destination.name;
      _destinationPredictions = [];
      _isSearchingDestination = false;
      _upsertDestinationMarker(destination);
    });

    _updateAllDriverMarkers();
    await _saveRecentDestination(destination);
    final area = await _resolveDestinationArea(destination);
    if (!mounted || _selectedDestination != destination) return;
    _setStateSafe(() {
      _selectedDestinationArea = area;
      _upsertDestinationMarker(destination);
    });

    if (_selectedOrigin != null) {
      await _drawRoute(showLoadingSnack: false);
    }

    if (mounted && _sheetController.isAttached) {
      await _sheetController.animateTo(
        _sheetMidSize,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    if (mounted) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Viaje anterior cargado'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }

    RepeatTripService.instance.clearPending();
  }

  // ========== MÉTODOS DE SERVICIO ACTIVO ==========

  /// Verifica si hay un servicio activo al iniciar la app
  Future<void> _checkActiveService() async {
    try {
      AppLogger.d('🔍 Verificando servicio activo al iniciar...');

      final servicio = await _activeServiceManager.getActiveService();

      if (servicio != null && servicio.isActivo) {
        AppLogger.d('✅ Servicio activo encontrado: ${servicio.id}');
        AppLogger.d('📊 Estado: ${servicio.estado.estado}');

        // Navegar a pantalla de servicio activo
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveServiceScreen(
              servicio: servicio,
              onServiceCompleted: () async {
                // Cuando el servicio se complete, volver al home
                if (mounted) {
                  Navigator.of(context).pop();

                  // Esperar un momento para que el backend actualice el estado del conductor
                  await Future.delayed(const Duration(seconds: 2));

                  // Recargar conductores disponibles después de completar el servicio
                  if (mounted) {
                    AppLogger.d(
                      '🔄 Recargando conductores disponibles al volver de servicio activo...',
                    );
                    _loadAvailableDrivers();
                  }
                }
              },
            ),
          ),
        );

        // Iniciar polling para actualizar el servicio
        _startServiceTracking(servicio.id);
      } else {
        AppLogger.d('ℹ️ No hay servicio activo');
      }
    } catch (e) {
      AppLogger.d('⚠️ Error verificando servicio activo: $e');
    }
  }

  /// Inicia el tracking del servicio activo
  void _startServiceTracking(int servicioId) {
    // Configurar callbacks
    _activeServiceManager.onServiceUpdated = (servicio) {
      if (!mounted) return;
      AppLogger.d('🔄 Servicio actualizado: ${servicio.estado.estado}');
      // TODO: Actualizar UI si es necesario
    };

    _activeServiceManager.onServiceCompleted = () {
      AppLogger.d('🏁 Servicio completado/cancelado');
      if (!mounted) return;

      // Usar WidgetsBinding para asegurar que se ejecute después del frame actual
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);

          // Esperar un momento para que el backend actualice el estado del conductor
          await Future.delayed(const Duration(seconds: 2));

          // Recargar conductores disponibles después de completar el servicio
          if (mounted) {
            AppLogger.d(
              '🔄 Recargando conductores disponibles después de finalizar servicio...',
            );
            _loadAvailableDrivers();
          }
        }
      });
    };

    // Iniciar polling
    _activeServiceManager.startPolling();

    // Suscribirse a eventos de Pusher
    _activeServiceManager.subscribeToServiceEvents(servicioId);
  }

  // ========== MÉTODOS DE CONDUCTORES DISPONIBLES ==========

  /// Configura el servicio de Pusher para conductores
  Future<void> _setupPusherConductores() async {
    try {
      // Por ahora usar empresa ID = 1 (puedes obtenerlo del backend si es necesario)
      const idEmpresa = 1;

      AppLogger.d('🚗 Configurando Pusher para conductores...');
      AppLogger.d('   🏢 Empresa ID: $idEmpresa');

      _pusherConductoresService = PusherConductoresService(
        idEmpresa: idEmpresa,
      );

      // Configurar callbacks
      _pusherConductoresService!.onDriverUpdate = (conductor) {
        if (!mounted) return;
        _updateDriverMarker(conductor);
      };

      _pusherConductoresService!.onDriverOffline = (conductorId) {
        if (!mounted) return;
        _removeDriverMarker(conductorId);
      };

      // Conectar al canal
      await _pusherConductoresService!.connect();

      AppLogger.d('✅ Pusher conductores configurado');
    } catch (e) {
      AppLogger.d('❌ Error configurando Pusher conductores: $e');
    }
  }

  /// Carga los conductores disponibles inicialmente
  Future<void> _loadAvailableDrivers({bool silent = false}) async {
    if (_currentPosition == null) {
      return;
    }

    try {
      final conductores = await _conductoresService.getConductoresDisponibles(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        radioKm: 15,
        maxAgeMinutes: 20,
      );

      if (!mounted) return;

      final receivedIds = conductores.map((c) => c.conductorId).toSet();
      for (final conductor in conductores) {
        _conductoresDisponibles[conductor.conductorId] = conductor;
      }

      for (final id in _conductoresDisponibles.keys.toList()) {
        if (!receivedIds.contains(id)) {
          _conductoresDisponibles.remove(id);
          _driverDisplayedPositions.remove(id);
          if (_selectedDirectDriver?.conductorId == id) {
            _selectedDirectDriver = null;
          }
        }
      }

      _seedDriverDisplayedPositions();
      _syncMarkersOnMap();

      if (!silent) {
        AppLogger.d('✅ ${conductores.length} conductores en mapa');
      }
    } catch (e) {
      if (!silent) {
        AppLogger.d('❌ Error cargando conductores: $e');
      }
    }
  }

  /// Actualiza datos del conductor (Pusher); el movimiento lo anima el ticker.
  void _updateDriverMarker(Conductor conductor) {
    if (!_showDrivers) return;
    if (conductor.estado?.toLowerCase() == 'desconectado') {
      _removeDriverMarker(conductor.conductorId);
      return;
    }
    if (_selectedDirectDriver?.conductorId == conductor.conductorId &&
        conductor.estado?.toLowerCase() != 'disponible') {
      _selectedDirectDriver = null;
    }
    _conductoresDisponibles[conductor.conductorId] = conductor;
    if (!_driverDisplayedPositions.containsKey(conductor.conductorId)) {
      _driverDisplayedPositions[conductor.conductorId] = LatLng(
        conductor.lat,
        conductor.lng,
      );
      _syncMarkersOnMap();
    }
  }

  /// Elimina el marcador de un conductor
  void _removeDriverMarker(int conductorId) {
    if (_selectedDirectDriver?.conductorId == conductorId) {
      _selectedDirectDriver = null;
    }
    _conductoresDisponibles.remove(conductorId);
    _driverDisplayedPositions.remove(conductorId);
    _syncMarkersOnMap();
  }

  Set<Marker> _buildDriverMarkers() {
    if (!_showDrivers) return {};

    final markers = <Marker>{};
    for (final conductor in _conductoresDisponibles.values) {
      final position =
          _driverDisplayedPositions[conductor.conductorId] ??
          LatLng(conductor.lat, conductor.lng);
      markers.add(
        Marker(
          markerId: MarkerId('driver_${conductor.conductorId}'),
          position: position,
          icon: conductor.estado?.toLowerCase() == 'ocupado'
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
              : (_driverMarkerIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    )),
          infoWindow: InfoWindow(
            title: '🚗 ${conductor.nombre}',
            snippet:
                '${conductor.estado?.toLowerCase() == 'ocupado' ? 'Ocupado • ' : ''}'
                '⭐ ${conductor.calificacion.toStringAsFixed(1)} • '
                '${conductor.vehiculo?.descripcion ?? "Sin vehículo"}',
          ),
          onTap: () => _onDriverMarkerTap(conductor),
          zIndexInt: 1,
        ),
      );
    }
    return markers;
  }

  /// Recompone marcadores del mapa (conductores animados + ruta + resto).
  void _syncMarkersOnMap() {
    if (!mounted || _isDisposed) return;

    final newMarkers = <Marker>{..._buildDriverMarkers()};

    if (_routeInfo != null &&
        _selectedOrigin != null &&
        _selectedDestination != null) {
      final originLatLng = LatLng(_selectedOrigin!.lat, _selectedOrigin!.lng);
      final destinationLatLng = LatLng(
        _selectedDestination!.lat,
        _selectedDestination!.lng,
      );
      final isOriginCurrentLocation =
          _selectedOrigin!.isCurrentLocation ||
          (_currentPosition != null &&
              _selectedOrigin!.lat == _currentPosition!.latitude &&
              _selectedOrigin!.lng == _currentPosition!.longitude);

      newMarkers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: originLatLng,
          icon: (isOriginCurrentLocation && _userMarkerIcon != null)
              ? _userMarkerIcon!
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
          infoWindow: InfoWindow(
            title: isOriginCurrentLocation ? 'Tu ubicación' : 'Origen',
            snippet: _selectedOrigin!.name,
          ),
        ),
      );
      newMarkers.add(
        _buildDestinationMarker(
          destinationLatLng,
          _destinationMarkerSnippet(_selectedDestination!),
        ),
      );
    } else {
      for (final marker in _markers) {
        final id = marker.markerId.value;
        if (id.startsWith('driver_') ||
            id == 'origin' ||
            id == 'user_location') {
          continue;
        }
        newMarkers.add(marker);
      }

      if (_currentPosition != null &&
          _routeInfo == null &&
          _userMarkerIcon != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            icon: _userMarkerIcon!,
            infoWindow: InfoWindow(
              title: _currentLocationName,
              snippet: _currentLocationAddress,
            ),
            zIndexInt: 10,
          ),
        );
      }
    }

    _setStateSafe(() => _markers = newMarkers);
  }

  void _updateAllDriverMarkers() => _syncMarkersOnMap();

  /// Crea el icono del marcador para conductores
  Future<void> _createDriverMarkerIcon() async {
    try {
      // Usar la imagen personalizada desde assets
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/marker.png',
      );

      _setStateSafe(() => _driverMarkerIcon = icon);
    } catch (e) {
      AppLogger.d('Error creando icono de conductor: $e');
      _setStateSafe(
        () => _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      );
    }
  }

  /// Crea un icono tipo punto para destino (sin usar pines por defecto de Google)
  Future<void> _createDestinationPointIcon() async {
    try {
      const double size = 28;
      const double outerRadius = 11;
      const double innerRadius = 6;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        const Offset(size / 2 + 0.8, size / 2 + 1.2),
        outerRadius,
        shadowPaint,
      );

      final Paint ringPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        outerRadius,
        ringPaint,
      );

      final Paint corePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        innerRadius,
        corePaint,
      );

      final ui.Image image = await recorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List? png = bytes?.buffer.asUint8List();
      if (png == null) return;

      _setStateSafe(() => _destinationPointIcon = BitmapDescriptor.bytes(png));
    } catch (e) {
      AppLogger.w('No se pudo crear icono punto de destino: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mapa de Google Maps
        _currentPosition == null
            ? Center(
                child: LocationStatusView(
                  isLoading: _isLoadingLocation,
                  message: _locationMessage,
                  onRetry: _initializeLocation,
                ),
              )
            : RepaintBoundary(
                child: StandardMap(
                  initialPosition: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  zoom: 15,
                  polylines: _polylines,
                  markers: _markers,
                  // onTap: _onMapTap,
                  // onLongPress: _onMapLongPress,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),

        // Overlay del mapa: solo escucha el extent, sin rebuild del árbol completo.
        if (_currentPosition != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _sheetExtent,
                builder: (context, extent, _) {
                  final progress =
                      ((extent - _sheetMinSize) /
                              (_sheetMaxSize - _sheetMinSize))
                          .clamp(0.0, 1.0);
                  return ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (progress * 0.18).clamp(0.0, 0.18),
                    ),
                  );
                },
              ),
            ),
          ),

        // Bottom sheet de viaje: un solo scroll continuo (sin saltos de layout).
        if (_currentPosition != null)
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _sheetMinSize,
              minChildSize: _sheetMinSize,
              maxChildSize: _sheetMaxSize,
              expand: false,
              snap: true,
              snapAnimationDuration: const Duration(milliseconds: 320),
              snapSizes: const [_sheetMinSize, _sheetMidSize, _sheetMaxSize],
              builder: (context, scrollController) {
                return _buildRideBottomSheet(scrollController);
              },
            ),
          ),

        // CTA flotante estilo inDrive (siempre visible cuando el viaje está listo).
        if (_currentPosition != null && _showFloatingRequestCta)
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, _) {
              final bottom = MediaQuery.sizeOf(context).height * extent + 10;
              return Positioned(
                left: 16,
                right: 16,
                bottom: bottom,
                child: _buildFloatingRequestCta(),
              );
            },
          ),

        // Tarjeta de contraoferta flotante (estilo InDrive)
        if (_showOffer && _currentOffer != null)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: SafeArea(
              child: DriverOfferCard(
                offerData: _currentOffer!,
                onAccept: _acceptOffer,
                onReject: _rejectOffer,
                onDismiss: _dismissOffer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRideBottomSheet(ScrollController scrollController) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSheetDragHandle(),
            Expanded(
              child: ListView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _sheetExtent,
                    builder: (context, extent, _) {
                      final showFormOnly = extent >= 0.24;
                      if (showFormOnly) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._buildTripFormChildren(showInlineActions: false),
                            const SizedBox(height: 88),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMinimizedContent(),
                          const SizedBox(height: 72),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetDragHandle() {
    return GestureDetector(
      onTap: _toggleSheet,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final originText = _selectedOrigin?.name ?? _currentLocationName;
    final hasDestination = _selectedDestination != null;
    final destinationText = hasDestination
        ? _destinationSummaryText(_selectedDestination!)
        : (_serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?');

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _openQuickRequestFlow,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasDestination
                ? AppColors.primary.withValues(alpha: 0.25)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.12)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDestination) ...[
              Text(
                destinationText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (_routeInfo != null) ...[
                const SizedBox(height: 8),
                RouteInfoCard(routeInfo: _routeInfo!, compact: true),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 14,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Desde: $originText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destinationText,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Desde: $originText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDestinationSummary() {
    final destination = _selectedDestination;
    if (destination == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final area = _selectedDestinationArea?.trim();
    final hasArea = area != null && area.isNotEmpty;
    final address = destination.address.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (hasArea) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Barrio: $area',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (address.isNotEmpty && address != destination.name) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTripFormChildren({required bool showInlineActions}) {
    return [
      ServiceTypeSelector(
        selectedType: _serviceType,
        onTypeChanged: (type) {
          _setStateSafe(() {
            _serviceType = type;
            _clearRoute();
          });
        },
      ),

      const SizedBox(height: 16),

      // Destino primero (flujo inDrive)
      LocationSearchField(
        controller: _destinationController,
        label: _serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?',
        icon: Icons.location_on,
        iconColor: AppColors.primary,
        focusNode: _destinationFocusNode,
        predictions: _destinationPredictions,
        isSearching: _isSearchingDestination,
        onSelectPrediction: _selectDestination,
        onClear: () {
          _setStateSafe(() {
            _destinationController.clear();
            _selectedDestination = null;
            _selectedDestinationArea = null;
            _destinationPredictions = [];
            _clearRoute();
          });
        },
      ),

      if (_recentDestinations.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildRecentDestinationChips(),
      ],

      const SizedBox(height: 14),

      // Origen (secundario, ya viene del GPS)
      LocationSearchField(
        controller: _originController,
        label: 'Recogida en',
        icon: Icons.my_location,
        iconColor: AppColors.green,
        predictions: _originPredictions,
        isSearching: _isSearchingOrigin,
        onSelectPrediction: _selectOrigin,
        onClear: () {
          _setStateSafe(() {
            _originController.clear();
            _selectedOrigin = null;
            _originPredictions = [];
          });
        },
      ),

      if (_selectedDestination != null && _routeInfo == null) ...[
        const SizedBox(height: 10),
        _buildSelectedDestinationSummary(),
      ],

      if (_selectedDestination != null &&
          _serviceType != 'taxi' &&
          _routeInfo == null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _saveFavoriteDestination('home'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Guardar Casa'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _saveFavoriteDestination('work'),
                icon: const Icon(Icons.work_outline, size: 18),
                label: const Text('Guardar Trabajo'),
              ),
            ),
          ],
        ),
      ],

      if (_routeInfo != null) ...[
        const SizedBox(height: 14),
        RouteInfoCard(routeInfo: _routeInfo!),
      ],

      if (showInlineActions &&
          _serviceType != 'taxi' &&
          _selectedOrigin != null &&
          _selectedDestination != null &&
          _routeInfo == null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isDrawingRoute ? null : _drawRoute,
              icon: const Icon(Icons.route),
              label: Text(
                _isDrawingRoute ? 'Calculando ruta...' : 'Calcular ruta',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),

      const SizedBox(height: 16),
    ];
  }

  Widget _buildFloatingRequestCta() {
    String label;
    String? subtitle;
    VoidCallback? onPressed;
    Color color;
    final isLoading = _isSubmittingRide ||
        (_isDrawingRoute && _serviceType != 'taxi');

    if (_needsRouteRetry) {
      label = _isDrawingRoute ? 'Calculando ruta...' : 'Calcular ruta';
      subtitle = 'Confirma el trayecto del domicilio';
      onPressed = isLoading ? null : _drawRoute;
      color = Colors.deepOrange;
    } else if (_canRequestRide) {
      label = _isSubmittingRide
          ? 'Buscando conductor...'
          : (_serviceType == 'taxi' ? 'Pedir taxi' : 'Pedir domicilio');
      if (_routeInfo != null) {
        subtitle = '${_routeInfo!.distance} · ${_routeInfo!.duration} · Taxímetro';
      } else if (_hasDestination) {
        subtitle = 'Destino confirmado · Taxímetro';
      } else {
        subtitle = 'Recogida en tu ubicación · Taxímetro';
      }
      onPressed = isLoading ? null : _requestRide;
      color = _serviceType == 'taxi'
          ? AppColors.primary
          : Colors.orange.shade600;
    } else {
      label = _serviceType == 'taxi'
          ? 'Elige destino o pide desde aquí'
          : 'Elige origen y destino';
      subtitle = null;
      onPressed = _hasOrigin ? _openQuickRequestFlow : null;
      color = Colors.grey;
    }

    return RideRequestFloatingCta(
      label: label,
      subtitle: subtitle,
      onPressed: onPressed,
      isLoading: isLoading,
      color: color,
    );
  }

  Widget _buildRecentDestinationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recientes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _recentDestinations
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(item.name),
                      avatar: const Icon(Icons.history, size: 16),
                      onPressed: () => _applyDestinationLocation(item),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  // Métodos de funcionalidad

  // Crear icono de marcador personalizado con la foto de perfil del usuario
  Future<void> _createUserMarkerIcon() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userPhotoUrl = authProvider.persona?.rutaFotoUrl;

      if (userPhotoUrl != null && userPhotoUrl.isNotEmpty) {
        // Intentar cargar la foto desde la URL
        final icon = await _getMarkerIconFromUrl(userPhotoUrl);
        if (icon != null) {
          _setStateSafe(() => _userMarkerIcon = icon);
          return;
        }
      }

      // Si no hay foto o falla la carga, usar icono por defecto
      _setStateSafe(
        () => _userMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    } catch (e) {
      // En caso de error, usar marcador por defecto
      _setStateSafe(
        () => _userMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    }
  }

  Future<BitmapDescriptor?> _getMarkerIconFromUrl(String imageUrl) async {
    try {
      const double markerSize = 46.0;
      const double shadowOffset = 1.0;
      const double outerInset = 2.0;
      const double imageInset = 4.0;
      const double borderWidth = 2.5;

      // Descargar la imagen
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      // Convertir a ui.Image
      final Uint8List imageData = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: markerSize.toInt(),
        targetHeight: markerSize.toInt(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      // Crear un canvas para dibujar el marcador circular
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final double size = markerSize;

      // Dibujar sombra exterior
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(
        Offset(size / 2 + shadowOffset, size / 2 + shadowOffset),
        (size / 2) - outerInset,
        shadowPaint,
      );

      // Dibujar círculo blanco como borde exterior
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        (size / 2) - outerInset,
        borderPaint,
      );

      // Guardar estado del canvas
      canvas.save();

      // Recortar la imagen en forma circular
      final Path clipPath = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(size / 2, size / 2),
            radius: (size / 2) - imageInset,
          ),
        );
      canvas.clipPath(clipPath);

      // Dibujar la imagen
      canvas.drawImageRect(
        frameInfo.image,
        Rect.fromLTWH(
          0,
          0,
          frameInfo.image.width.toDouble(),
          frameInfo.image.height.toDouble(),
        ),
        Rect.fromLTWH(
          imageInset,
          imageInset,
          size - (imageInset * 2),
          size - (imageInset * 2),
        ),
        Paint()..filterQuality = FilterQuality.high,
      );

      // Restaurar estado del canvas
      canvas.restore();

      // Dibujar borde de color accent (naranja)
      final Paint accentBorderPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        (size / 2) - borderWidth,
        accentBorderPaint,
      );

      // Convertir a imagen
      final ui.Image markerImage = await pictureRecorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final ByteData? byteData = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        return BitmapDescriptor.bytes(pngBytes);
      }
    } catch (e) {
      AppLogger.d('Error creando marcador personalizado: $e');
    }
    return null;
  }

  // Obtener nombre y dirección desde coordenadas (Geocoding reverso)
  Future<CurrentLocationData> _getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    return _reverseGeocodingService.resolveCurrentLocationLabel(
      lat: lat,
      lng: lng,
    );
  }

  Future<void> _initializeLocation() async {
    _setStateSafe(() {
      _isLoadingLocation = true;
      _locationMessage = 'Verificando permisos...';
    });

    bool permissionGranted = await _checkAndRequestPermissions();

    if (!permissionGranted) {
      _setStateSafe(() {
        _isLoadingLocation = false;
        _locationMessage = 'Permisos de ubicación denegados';
      });
      return;
    }

    await _getCurrentLocation();
  }

  Future<bool> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    return status.isGranted;
  }

  Future<void> _getCurrentLocation() async {
    try {
      _setStateSafe(() => _locationMessage = 'Obteniendo ubicación...');

      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (lastKnown != null && mounted) {
        _applyOriginFromGps(lastKnown, markReady: true);
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        if (lastKnown != null) {
          position = lastKnown;
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      _applyOriginFromGps(position, markReady: true);
      unawaited(_refineOriginAddress(position));

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }

      unawaited(_loadAvailableDrivers());
      _startDriversRefreshTimer();
      unawaited(_requestNotificationPermissionAfterLocation());
      _tryApplyPendingRepeatTrip();
    } catch (e) {
      if (mounted) {
        _setStateSafe(() {
          _isLoadingLocation = false;
          _locationMessage = 'Error al obtener ubicación';
        });
      }
    }
  }

  void _applyOriginFromGps(Position position, {required bool markReady}) {
    _setStateSafe(() {
      _currentPosition = position;
      if (markReady) {
        _isLoadingLocation = false;
        _locationMessage = 'Listo para pedir servicio';
      }

      _selectedOrigin = TripLocation.currentLocation(
        lat: position.latitude,
        lng: position.longitude,
        name: _currentLocationName,
        address: _currentLocationAddress,
      );

      if (_originController.text.trim().isEmpty) {
        _originController.removeListener(_onOriginChanged);
        _originController.text = _currentLocationName;
        _originController.addListener(_onOriginChanged);
      }

      if (_markers.isEmpty && _userMarkerIcon != null) {
        _markers = {
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(position.latitude, position.longitude),
            icon: _userMarkerIcon!,
            infoWindow: InfoWindow(
              title: _currentLocationName,
              snippet: _currentLocationAddress,
            ),
          ),
        };
      }
    });
  }

  Future<void> _refineOriginAddress(Position position) async {
    final locationData = await _getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (!mounted) return;

    _setStateSafe(() {
      _currentLocationName = locationData.name;
      _currentLocationAddress = locationData.address;

      if (_selectedOrigin != null) {
        _selectedOrigin = TripLocation.currentLocation(
          lat: position.latitude,
          lng: position.longitude,
          name: _currentLocationName,
          address: _currentLocationAddress,
        );
        _originController.removeListener(_onOriginChanged);
        _originController.text = _currentLocationName;
        _originController.addListener(_onOriginChanged);
      }
    });
  }

  Future<void> _requestNotificationPermissionAfterLocation() async {
    if (!mounted || _notificationPermissionRequestedInSession) return;
    _notificationPermissionRequestedInSession = true;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isPermanentlyDenied) return;
      await Permission.notification.request();
    } catch (_) {
      // Silencioso: no bloquear flujo de ubicación por fallo de permisos de notificación.
    }
  }

  void _toggleSheet() {
    if (_isExpanded) {
      _minimizeSheet();
    } else {
      _expandSheet();
    }
  }

  Future<void> _expandSheet() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      _sheetMidSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _destinationFocusNode.requestFocus();
  }

  Future<void> _minimizeSheet() async {
    if (!_sheetController.isAttached) return;
    FocusScope.of(context).unfocus();
    await _sheetController.animateTo(
      _sheetMinSize,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openQuickRequestFlow() async {
    await _expandSheet();
  }

  // --- Selección de destino en el mapa (deshabilitado) ---
  // Future<void> _onMapTap(LatLng latLng) async {
  //   await _setDestinationFromMap(
  //     latLng,
  //     showToast: true,
  //     routeWithLoading: false,
  //   );
  // }
  //
  // Future<void> _onMapLongPress(LatLng latLng) async {
  //   await _setDestinationFromMap(
  //     latLng,
  //     showToast: true,
  //     routeWithLoading: true,
  //   );
  // }

  Marker _buildDestinationMarker(LatLng position, String snippet) {
    return Marker(
      markerId: const MarkerId('destination'),
      position: position,
      icon:
          _destinationPointIcon ??
          _driverMarkerIcon ??
          BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(title: 'Destino seleccionado', snippet: snippet),
      draggable: false,
      // onDragEnd: _onDestinationMarkerDragged,
      zIndexInt: 6,
    );
  }

  String _destinationSummaryText(TripLocation destination) {
    final area = _selectedDestinationArea?.trim();
    if (area != null && area.isNotEmpty) {
      return '${destination.name} • Barrio: $area';
    }
    if (destination.address.trim().isNotEmpty &&
        destination.address != destination.name) {
      return '${destination.name} • ${destination.address}';
    }
    return destination.name;
  }

  String _destinationMarkerSnippet(TripLocation destination) {
    final area = _selectedDestinationArea?.trim();
    final address = destination.address.trim();
    if (area != null && area.isNotEmpty) {
      return address.isNotEmpty && address != destination.name
          ? 'Barrio: $area • $address'
          : 'Barrio: $area';
    }
    return address.isNotEmpty ? address : destination.name;
  }

  Future<String?> _resolveDestinationArea(TripLocation destination) {
    return _reverseGeocodingService.resolveAreaName(
      lat: destination.lat,
      lng: destination.lng,
    );
  }

  void _upsertDestinationMarker(TripLocation destination) {
    final nextMarkers = <Marker>{};
    for (final marker in _markers) {
      if (marker.markerId.value == 'destination') continue;
      nextMarkers.add(marker);
    }
    nextMarkers.add(
      _buildDestinationMarker(
        LatLng(destination.lat, destination.lng),
        _destinationMarkerSnippet(destination),
      ),
    );
    _markers = nextMarkers;
  }

  // Future<void> _onDestinationMarkerDragged(LatLng latLng) async {
  //   await _setDestinationFromMap(
  //     latLng,
  //     showToast: false,
  //     routeWithLoading: false,
  //   );
  // }

  // Future<void> _setDestinationFromMap(
  //   LatLng latLng, {
  //   required bool showToast,
  //   required bool routeWithLoading,
  // }) async { ... }

  String _prefKey(String suffix) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.id ?? 0;
    return 'pasajero_${uid}_$suffix';
  }

  Map<String, dynamic> _tripLocationToMap(TripLocation loc) {
    return {
      'placeId': loc.placeId,
      'name': loc.name,
      'address': loc.address,
      'lat': loc.lat,
      'lng': loc.lng,
      'isCurrentLocation': loc.isCurrentLocation,
    };
  }

  TripLocation? _tripLocationFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return TripLocation(
      placeId: map['placeId']?.toString(),
      name: map['name']?.toString() ?? 'Destino',
      address: map['address']?.toString() ?? '',
      lat: lat,
      lng: lng,
      isCurrentLocation: map['isCurrentLocation'] == true,
    );
  }

  Future<void> _loadSavedPassengerLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentRaw = prefs.getString(_prefKey('recent_destinations'));

      List<TripLocation> recent = [];

      if (recentRaw != null && recentRaw.isNotEmpty) {
        final list = (jsonDecode(recentRaw) as List)
            .map(
              (e) => _tripLocationFromMap((e as Map).cast<String, dynamic>()),
            )
            .whereType<TripLocation>()
            .toList();
        recent = list;
      }

      if (!mounted) return;
      _setStateSafe(() {
        _recentDestinations = recent;
      });
    } catch (e) {
      AppLogger.w('No se pudieron cargar ubicaciones guardadas: $e');
    }
  }

  Future<void> _saveFavoriteDestination(String type) async {
    final selected = _selectedDestination;
    if (selected == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey(type),
        jsonEncode(_tripLocationToMap(selected)),
      );
      if (!mounted) return;
      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text(
            type == 'home'
                ? 'Casa guardada correctamente'
                : 'Trabajo guardado correctamente',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      AppLogger.w('No se pudo guardar favorito $type: $e');
    }
  }

  Future<void> _saveRecentDestination(TripLocation destination) async {
    try {
      final next = <TripLocation>[destination];
      for (final item in _recentDestinations) {
        final samePlace =
            item.placeId != null &&
            destination.placeId != null &&
            item.placeId == destination.placeId;
        final sameCoords =
            (item.lat - destination.lat).abs() < 0.00001 &&
            (item.lng - destination.lng).abs() < 0.00001;
        if (samePlace || sameCoords) continue;
        next.add(item);
      }

      final capped = next.take(6).toList();
      _setStateSafe(() => _recentDestinations = capped);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey('recent_destinations'),
        jsonEncode(capped.map(_tripLocationToMap).toList()),
      );
    } catch (e) {
      AppLogger.w('No se pudo guardar reciente: $e');
    }
  }

  Future<void> _applyDestinationLocation(TripLocation destination) async {
    final area = await _resolveDestinationArea(destination);
    if (!mounted) return;

    _setStateSafe(() {
      _selectedDestination = destination;
      _selectedDestinationArea = area;
      _destinationController.text = destination.name;
      _isSearchingDestination = false;
      _destinationPredictions = [];
      _upsertDestinationMarker(destination);
    });
    await _saveRecentDestination(destination);
    _updateAllDriverMarkers();
    if (_selectedOrigin != null) {
      await _drawRoute();
    }
  }

  _SheetVisualState _sheetStateFromExtent(double extent) {
    // Histéresis amplia para evitar rebotes visuales entre estados.
    const double hysteresis = 0.04;
    final toMiddle = (_sheetMinSize + _sheetMidSize) / 2;
    final toExpanded = (_sheetMidSize + _sheetMaxSize) / 2;

    switch (_sheetVisualState) {
      case _SheetVisualState.compact:
        return extent > (toMiddle + hysteresis)
            ? _SheetVisualState.middle
            : _SheetVisualState.compact;
      case _SheetVisualState.middle:
        if (extent < (toMiddle - hysteresis)) {
          return _SheetVisualState.compact;
        }
        if (extent > (toExpanded + hysteresis)) {
          return _SheetVisualState.expanded;
        }
        return _SheetVisualState.middle;
      case _SheetVisualState.expanded:
        return extent < (toExpanded - hysteresis)
            ? _SheetVisualState.middle
            : _SheetVisualState.expanded;
    }
  }

  void _emitSnapHapticIfNeeded(double extent, _SheetVisualState visualState) {
    const epsilon = 0.015;
    final isAtSnap =
        (extent - _sheetMinSize).abs() <= epsilon ||
        (extent - _sheetMidSize).abs() <= epsilon ||
        (extent - _sheetMaxSize).abs() <= epsilon;
    if (!isAtSnap) return;
    if (_lastHapticSnap == visualState) return;

    _lastHapticSnap = visualState;
    switch (visualState) {
      case _SheetVisualState.compact:
      case _SheetVisualState.middle:
        HapticFeedback.selectionClick();
        break;
      case _SheetVisualState.expanded:
        HapticFeedback.lightImpact();
        break;
    }
  }

  void _onOriginChanged() {
    if (!mounted) return;
    final query = _originController.text.trim();
    _originSearchDebounce?.cancel();

    if (query.isEmpty) {
      _setStateSafe(() {
        _originPredictions = [];
        _isSearchingOrigin = false;
      });
      if (_destinationController.text.trim().isEmpty) {
        _placesService.clearAutocompleteSession();
      }
      return;
    }

    _setStateSafe(() => _isSearchingOrigin = true);
    final requestId = ++_originSearchRequestId;
    _originSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final predictions = await _placesService.getAutocompletePredictions(
        query,
      );
      if (!mounted || requestId != _originSearchRequestId) return;
      _setStateSafe(() {
        _originPredictions = predictions;
        _isSearchingOrigin = false;
      });
    });
  }

  void _onDestinationChanged() {
    if (!mounted) return;
    final query = _destinationController.text.trim();
    _destinationSearchDebounce?.cancel();

    if (query.isEmpty) {
      _setStateSafe(() {
        _destinationPredictions = [];
        _isSearchingDestination = false;
      });
      if (_originController.text.trim().isEmpty) {
        _placesService.clearAutocompleteSession();
      }
      return;
    }

    _setStateSafe(() => _isSearchingDestination = true);
    final requestId = ++_destinationSearchRequestId;
    _destinationSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final predictions = await _placesService.getAutocompletePredictions(
          query,
        );
        if (!mounted || requestId != _destinationSearchRequestId) return;
        _setStateSafe(() {
          _destinationPredictions = predictions;
          _isSearchingDestination = false;
        });
      },
    );
  }

  Future<void> _selectOrigin(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _originController.removeListener(_onOriginChanged);

    final details = await _placesService.getPlaceDetails(
      prediction.placeId,
      sessionToken: _placesService.currentAutocompleteSessionToken,
    );

    if (details != null && mounted) {
      _setStateSafe(() {
        _selectedOrigin = TripLocation.fromPlaceDetails(
          placeId: prediction.placeId,
          name: details.name,
          address: details.address,
          lat: details.lat,
          lng: details.lng,
        );
        _originController.text = prediction.mainText;
        _originPredictions = [];
        _isSearchingOrigin = false;
      });

      // Restaurar listener
      _originController.addListener(_onOriginChanged);

      // Si ya hay destino seleccionado, calcular ruta automáticamente.
      if (_selectedDestination != null) {
        await _drawRoute();
      }
    }
  }

  Future<void> _selectDestination(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _destinationController.removeListener(_onDestinationChanged);

    final details = await _placesService.getPlaceDetails(
      prediction.placeId,
      sessionToken: _placesService.currentAutocompleteSessionToken,
    );

    if (details != null && mounted) {
      final destination = TripLocation.fromPlaceDetails(
        placeId: prediction.placeId,
        name: details.name,
        address: details.address,
        lat: details.lat,
        lng: details.lng,
      );

      _setStateSafe(() {
        _selectedDestination = destination;
        _selectedDestinationArea = null;
        _destinationController.text = prediction.mainText;
        _destinationPredictions = [];
        _isSearchingDestination = false;
        _upsertDestinationMarker(destination);
      });

      _destinationController.addListener(_onDestinationChanged);
      unawaited(_saveRecentDestination(destination));
      _updateAllDriverMarkers();

      unawaited(
        _resolveDestinationArea(destination).then((area) {
          if (!mounted || _selectedDestination != destination) return;
          _setStateSafe(() {
            _selectedDestinationArea = area;
            _upsertDestinationMarker(destination);
          });
        }),
      );

      if (_selectedOrigin != null) {
        unawaited(_drawRoute());
      }

      FocusScope.of(context).unfocus();
      if (_sheetController.isAttached) {
        unawaited(_minimizeSheet());
      }
    }
  }

  Future<void> _drawRoute({bool showLoadingSnack = false}) async {
    if (_selectedOrigin == null || _selectedDestination == null) return;

    _setStateSafe(() => _isDrawingRoute = true);

    try {
      final originLatLng = LatLng(_selectedOrigin!.lat, _selectedOrigin!.lng);
      final destinationLatLng = LatLng(
        _selectedDestination!.lat,
        _selectedDestination!.lng,
      );

      final routeInfo = await _routesService.getRoute(
        origin: originLatLng,
        destination: destinationLatLng,
      );

      if (routeInfo != null && mounted) {
        _setStateSafe(() {
          _routeInfo = routeInfo;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeInfo.polylinePoints,
              color: Colors.deepOrange,
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          };
        });

        _syncMarkersOnMap();
        _fitCameraToBounds(routeInfo.polylinePoints);

        FocusScope.of(context).unfocus();
        if (_isExpanded) {
          unawaited(_minimizeSheet());
        }
      } else if (mounted && showLoadingSnack) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(
            content: Text('No se pudo calcular la ruta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _setStateSafe(() => _isDrawingRoute = false);
      }
    }
  }

  void _fitCameraToBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _clearRoute() {
    _setStateSafe(() {
      _routeInfo = null;
      _polylines = {};
      _markers = {};
      _selectedDestination = null;
      _selectedDestinationArea = null;
      _destinationController.clear();
    });

    if (_currentPosition != null) {
      _centerToCurrentLocation();
    }
  }

  void _centerToCurrentLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _requestRide() {
    if (_isSubmittingRide) return;
    _handleRideConfirmation();
  }

  bool _isNoDriversAvailableMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('no tiene carros disponibles') ||
        normalized.contains('no hay carros disponibles') ||
        normalized.contains('no hay conductores disponibles') ||
        normalized.contains('sin conductores disponibles');
  }

  Future<void> _showNoDriversAvailableDialog(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return NoDriversAvailableDialog(
          message: message,
          onClose: () => Navigator.of(dialogContext).pop(),
          onRetry: () {
            Navigator.of(dialogContext).pop();
            _requestRide();
          },
        );
      },
    );
  }

  Future<void> _handleRideConfirmation() async {
    if (_isSubmittingRide) return;

    final isDelivery = _serviceType == 'domicilio';
    final origin = _selectedOrigin;
    final destination = _selectedDestination;
    final route = _routeInfo;
    final pasajeroId =
        Provider.of<AuthProvider>(context, listen: false).idPersona ?? 0;

    if (!mounted) return;
    if (origin == null) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Selecciona el punto de origen'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (isDelivery && destination == null) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Para domicilio debes seleccionar destino'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (isDelivery && route == null) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo calcular la ruta del domicilio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (pasajeroId <= 0) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar el pasajero de la sesión'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool isDirectFlow = _selectedDirectDriver != null;
    final Conductor? selectedConductor = _selectedDirectDriver;

    _setStateSafe(() => _isSubmittingRide = true);

    try {
      final response = isDirectFlow
          ? await _rideRequestService.sendDirectOffer(
              conductorId: selectedConductor!.conductorId,
              pasajeroId: pasajeroId,
              origin: origin,
              destination: destination,
              distancia: route?.distance,
              duracionEstimada: route?.duration,
              precioOfrecido: 0,
            )
          : await _rideRequestService.requestRide(
              origin: origin,
              destination: destination,
              distance: route?.distance,
              distanceValue: route?.distanceValue,
              duration: route?.duration,
              durationValue: route?.durationValue,
              serviceType: isDelivery ? 'domicilio' : 'taxi',
            );

      if (!mounted) return;

      final servicioId = _parseServicioIdFromResponse(response);
      if (servicioId == null) {
        AppLogger.d('⚠️ No se pudo obtener servicio_id de la respuesta');
        AppLogger.d('   Response completo: $response');
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(
            content: Text('No se pudo confirmar el servicio. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      AppLogger.d('🚀 PASAJERO: Navegando a PasajeroEsperandoConductorScreen');
      AppLogger.d('   Servicio ID: $servicioId');

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PasajeroEsperandoConductorScreen(
            servicioId: servicioId,
            datosServicio: {
              if (selectedConductor != null)
                'conductor_id': selectedConductor.conductorId,
              'origen_lat': origin.lat,
              'origen_lng': origin.lng,
              'origen_address': origin.address,
              'destino_lat': destination?.lat,
              'destino_lng': destination?.lng,
              'destino_address': destination?.address ?? 'Destino no definido',
              'precio_ofrecido': 0,
            },
          ),
        ),
      );
    } on TaxiEnServicioException catch (e) {
      if (!mounted) return;

      final servicioId = e.servicioActivoId;
      if (servicioId != null) {
        final restoration = ActiveServiceRestorationService();
        final detalle = await restoration.verificarServicioActivoPasajero();
        if (!mounted) return;

        if (detalle != null &&
            ServiceNavigationHelper.shouldShowActiveService(detalle)) {
          await ServiceNavigationHelper.navigateToActiveService(
            context,
            detalle,
            Provider.of<AuthProvider>(context, listen: false),
          );
        } else {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PasajeroEsperandoConductorScreen(
                servicioId: servicioId,
                datosServicio: {'id': servicioId},
              ),
            ),
          );
        }
        return;
      }

      _scaffoldMessenger?.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted || _scaffoldMessenger == null) return;

      var errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      if (errorMessage.contains('TimeoutException') ||
          errorMessage.contains('receive timeout') ||
          errorMessage.contains('tiempo de espera')) {
        errorMessage =
            'La solicitud tardó demasiado. Revisa tu conexión e intenta de nuevo.';
      }

      if (_isNoDriversAvailableMessage(errorMessage)) {
        await _showNoDriversAvailableDialog(errorMessage);
      } else {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        _setStateSafe(() => _isSubmittingRide = false);
      }
    }
  }

  int? _parseServicioIdFromResponse(Map<String, dynamic> response) {
    if (response['solicitud_id'] != null) {
      return int.tryParse(response['solicitud_id'].toString());
    }
    if (response['servicio'] is Map) {
      final id = (response['servicio'] as Map)['id'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '');
    }
    if (response['data'] is Map) {
      final id = (response['data'] as Map)['id'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '');
    }
    if (response['servicio_id'] != null) {
      final id = response['servicio_id'];
      if (id is int) return id;
      return int.tryParse(id.toString());
    }
    return null;
  }

  Future<void> _onDriverMarkerTap(Conductor conductor) async {
    final alreadySelected =
        _selectedDirectDriver?.conductorId == conductor.conductorId;

    _setStateSafe(() {
      _selectedDirectDriver = alreadySelected ? null : conductor;
    });

    _showDriverSelectionToast(
      alreadySelected
          ? 'Conductor deseleccionado'
          : 'Conductor seleccionado: ${conductor.nombre}',
      isSelected: !alreadySelected,
    );

    if (alreadySelected) return;

    final canSendDirectNow =
        _selectedOrigin != null &&
        (_serviceType == 'taxi' ||
            (_selectedDestination != null && _routeInfo != null));

    if (!canSendDirectNow) {
      return;
    }

    await _handleRideConfirmation();
  }

  void _showDriverSelectionToast(String message, {required bool isSelected}) {
    if (_scaffoldMessenger == null) return;
    _scaffoldMessenger!
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          backgroundColor: isSelected
              ? Colors.green.shade700
              : Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(milliseconds: 1700),
          content: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ========== MÉTODOS DE PUSHER - CONTRAOFERTAS ==========

  /// Configura la conexión a Pusher para recibir la confirmación de solicitud creada
  Future<void> _setupPusherRequestConfirmation() async {
    try {
      AppLogger.d('🚀 Configurando Pusher para confirmación de solicitudes...');

      // Suscribirse al canal de solicitudes-servicio (conexión secundaria)
      await PusherService.subscribeSecondary('solicitudes-servicio');

      // Registrar handlers para variantes del evento
      for (final eventName in const ['nueva-solicitud', 'nueva_solicitud']) {
        PusherService.registerEventHandlerSecondary(
          'solicitudes-servicio:$eventName',
          _manejarNuevaSolicitud,
        );
      }

      AppLogger.d(
        '✅ Pusher configurado - Esperando confirmación en canal solicitudes-servicio',
      );
    } catch (e) {
      AppLogger.d('❌ Error configurando Pusher: $e');
    }
  }

  /// Maneja la llegada de la confirmación de solicitud creada
  void _manejarNuevaSolicitud(dynamic data) {
    AppLogger.d('🚕 _manejarNuevaSolicitud llamado en PASAJERO');
    AppLogger.d('📦 Tipo de datos: ${data.runtimeType}');
    AppLogger.d('📦 Datos recibidos: $data');

    if (!mounted) {
      AppLogger.d('⚠️ Widget no montado, ignorando solicitud');
      return;
    }

    try {
      Map<String, dynamic> solicitudData;

      // Manejar diferentes tipos de datos
      if (data is String) {
        // Si viene como JSON string, parsearlo
        solicitudData = Map<String, dynamic>.from(
          const JsonDecoder().convert(data) as Map,
        );
      } else if (data is Map) {
        solicitudData = Map<String, dynamic>.from(data);
      } else {
        AppLogger.d('⚠️ Tipo de datos no soportado: ${data.runtimeType}');
        return;
      }

      AppLogger.d('✅ Datos parseados correctamente');
      AppLogger.d('🔍 Contenido:');
      AppLogger.d('   - servicio_id: ${solicitudData['servicio_id']}');
      AppLogger.d('   - success: ${solicitudData['success']}');
      AppLogger.d('   - message: ${solicitudData['message']}');

      // Verificar que el widget aún esté montado
      if (!mounted) return;

      // Verificar que la solicitud sea para este pasajero
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.idPersona;

      // Obtener el pasajero_id de los datos o del data anidado
      final pasajeroId =
          solicitudData['pasajero_id'] ?? solicitudData['data']?['pasajero_id'];

      AppLogger.d(
        '👤 Usuario actual: $currentUserId, Solicitud para: $pasajeroId',
      );

      if (currentUserId == pasajeroId) {
        AppLogger.d('✅ La solicitud es para este pasajero');

        // Mostrar notificación de solicitud confirmada
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text(
                solicitudData['message'] ??
                    '✅ Solicitud confirmada. Esperando conductores...',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        AppLogger.d('⏭️ Solicitud no es para este pasajero, ignorando');
      }
    } catch (e, stackTrace) {
      AppLogger.d('⚠️ Error procesando solicitud: $e');
      AppLogger.d('📍 Stack trace: $stackTrace');
    }
  }

  /// Configura la conexión a Pusher para recibir contraofertas
  Future<void> _setupPusherOffers() async {
    if (!_enableGlobalOffersChannel) {
      AppLogger.d('⏭️ Canal ofertas-globales deshabilitado');
      return;
    }

    try {
      AppLogger.d('🚀 Configurando Pusher para ofertas globales...');

      // Suscribirse al canal de ofertas globales (conexión secundaria)
      await PusherService.subscribeSecondary('ofertas-globales');

      // Registrar el handler para nueva oferta
      PusherService.registerEventHandlerSecondary(
        'ofertas-globales:nueva-oferta',
        _handleNewOffer,
      );

      AppLogger.d(
        '✅ Pusher configurado - Esperando ofertas en canal ofertas-globales',
      );
    } catch (e) {
      AppLogger.d('❌ Error configurando Pusher: $e');
    }
  }

  /// Maneja la llegada de una nueva contraoferta
  void _handleNewOffer(dynamic data) {
    AppLogger.d('🎉 ¡Nueva contraoferta recibida!');
    AppLogger.d('📦 Data tipo: ${data.runtimeType}');
    AppLogger.d('📦 Data completa: $data');

    try {
      // Parsear data si viene como string
      Map<String, dynamic> offerData;
      if (data is String) {
        offerData = jsonDecode(data);
      } else {
        offerData = Map<String, dynamic>.from(data);
      }

      AppLogger.d('🔍 Datos parseados:');
      AppLogger.d('   - oferta_id: ${offerData['oferta_id']}');
      AppLogger.d('   - solicitud_id: ${offerData['solicitud_id']}');
      AppLogger.d('   - pasajero_id: ${offerData['pasajero_id']}');
      AppLogger.d('   - conductor_nombre: ${offerData['conductor_nombre']}');
      AppLogger.d('   - precio_ofertado: ${offerData['precio_ofertado']}');

      // Verificar que el widget aún esté montado
      if (!mounted) return;

      // Verificar que la oferta sea para este pasajero
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.idPersona;
      final offerPassengerId = offerData['pasajero_id'];

      AppLogger.d(
        '👤 Usuario actual: $currentUserId, Oferta para: $offerPassengerId',
      );

      if (currentUserId == offerPassengerId) {
        if (!mounted) return;

        _setStateSafe(() {
          _currentOffer = offerData;
          _showOffer = true;
        });

        AppLogger.d('✅ Oferta mostrada al usuario');

        // Mostrar snackbar de notificación
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text(
                '🚗 Nueva oferta de ${offerData['conductor_nombre']} - \$${offerData['precio_ofertado']}',
              ),
              backgroundColor: AppColors.accent,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        AppLogger.d('⏭️ Oferta no es para este pasajero, ignorando');
      }
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error procesando oferta: $e');
      AppLogger.d('📍 Stack trace: $stackTrace');
    }
  }

  /// Acepta la contraoferta del conductor
  void _acceptOffer() {
    if (_currentOffer == null) return;

    AppLogger.d('✅ Aceptando oferta: ${_currentOffer!['oferta_id']}');

    // TODO: Llamar al backend para confirmar la aceptación
    // await _rideRequestService.acceptOffer(_currentOffer!['oferta_id']);

    if (!mounted) return;

    if (_scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text(
            '✅ ¡Oferta aceptada! El conductor ${_currentOffer!['conductor_nombre']} va en camino',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    _setStateSafe(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }

  /// Rechaza la contraoferta del conductor
  void _rejectOffer() {
    if (_currentOffer == null) return;

    AppLogger.d('❌ Rechazando oferta: ${_currentOffer!['oferta_id']}');

    // TODO: Llamar al backend para notificar el rechazo
    // await _rideRequestService.rejectOffer(_currentOffer!['oferta_id']);

    if (!mounted) return;

    if (_scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        const SnackBar(
          content: Text('Oferta rechazada. Esperando más conductores...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }

    _setStateSafe(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }

  /// Cierra la oferta sin aceptar ni rechazar
  void _dismissOffer() {
    _setStateSafe(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }
}
