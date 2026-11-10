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
import 'package:intellitaxi/features/pasajero/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/conductor/data/conductor_model.dart';
// import 'package:intellitaxi/features/pasajero/travel_assistant/travel_assistant_screen.dart';
import 'package:intellitaxi/features/pasajero/widgets/no_drivers_available_dialog.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/core/geo/place_precision.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:intellitaxi/core/services/service_navigation_helper.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/core/widgets/map_dot_marker_factory.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_active_service_controller.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_nearby_drivers_controller.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_places_search_controller.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_socket_offers_controller.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/device_location_service.dart';
import 'package:intellitaxi/core/services/precise_gps.dart';
import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';
import 'package:intellitaxi/core/utils/safe_image_decode.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/pasajero/data/service_pin.dart';
import 'package:intellitaxi/features/pasajero/services/barrios_api_service.dart';
import 'package:intellitaxi/features/pasajero/widgets/barrio_search_sheet.dart';
import 'package:intellitaxi/features/pasajero/widgets/map_center_pin.dart';
import 'package:intellitaxi/features/pasajero/widgets/pasajero_home_ride_sheet.dart';

class HomePasajero extends StatefulWidget {
  final List<dynamic> stories;

  const HomePasajero({super.key, required this.stories});

  @override
  State<HomePasajero> createState() => _HomePasajeroState();
}

enum _SheetVisualState { compact, middle, expanded }

class _HomePasajeroState extends State<HomePasajero>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Vista cenital tipo apps de movilidad (sin inclinación 3D).
  static const double _mapZoomPasajero = 16.5;
  static const double _mapTiltPasajero = 0;
  static const double _mapBearingPasajero = 0;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Position? _rawGpsPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Verificando tu ubicación actual con GPS de alta precisión...';
  String _locationActionLabel = 'Reintentar ubicación';
  IconData _locationActionIcon = Icons.refresh_rounded;
  bool _locationNeedsSettings = false;

  // Para el bottom sheet con snap
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  static const double _sheetMinSize = 0.48;
  static const double _sheetMidSize = 0.58;
  static const double _sheetMaxSize = 0.90;
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_sheetMidSize);
  double _sheetSize = _sheetMidSize;
  _SheetVisualState _sheetVisualState = _SheetVisualState.middle;
  _SheetVisualState? _lastHapticSnap;

  // Para las búsquedas
  final PlacesService _placesService = PlacesService();
  final RoutesService _routesService = RoutesService();
  final RideRequestService _rideRequestService = RideRequestService();
  final ReverseGeocodingService _reverseGeocodingService =
      ReverseGeocodingService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
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
  bool _isResolvingMapDestination = false;
  late final PasajeroPlacesSearchController _placesSearch;
  final PasajeroSocketOffersController _socketOffers =
      PasajeroSocketOffersController();
  bool _isProcessingOffer = false;

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

  final PasajeroActiveServiceController _activeServiceController =
      PasajeroActiveServiceController();

  // Referencia segura al ScaffoldMessenger
  ScaffoldMessengerState? _scaffoldMessenger;

  // Conductores disponibles en mapa
  final PasajeroNearbyDriversController _nearbyDrivers =
      PasajeroNearbyDriversController();
  final bool _showDrivers = true; // Toggle para mostrar/ocultar conductores
  Ticker? _driverMarkersTicker;
  Timer? _driversRefreshTimer;
  DateTime? _lastMarkerSyncAt;
  int _idleMarkerTicks = 0;
  bool _isDisposed = false;
  String _currentLocationName = 'Mi ubicación';
  String _currentLocationAddress = 'Mi ubicación actual';
  String? _currentLocationArea;
  String? _currentLocationStreet;
  bool _prefsLoaded = false;
  List<TripLocation> _recentDestinations = [];
  TripLocation? _favoriteHome;
  TripLocation? _favoriteWork;
  bool _editingPickup = false;
  bool _notificationPermissionRequestedInSession = false;

  final BarrioResolver _barrioResolver = BarrioResolver();
  late final ServicePin _pickupPin = ServicePin(
    lat: PopayanUrbanArea.centerLat,
    lng: PopayanUrbanArea.centerLng,
  );
  ServicePin? _destPin;
  int _destPinGeneration = 0;
  bool _mapMoving = false;
  bool _programmaticCamera = false;
  int _programmaticCameraDepth = 0;
  LatLng? _programmaticTarget;

  /// `onCameraIdle` de un movimiento nuestro llega después de `animateCamera`.
  /// Solo se ignora si la cámara sigue en el punto al que la mandamos.
  DateTime _programmaticIdleUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// El usuario eligió una dirección de recogida. Ni el GPS ni el encuadre
  /// de la ruta pueden reemplazarla.
  bool _namedPickupLocked = false;
  LatLng? _lastCameraTarget;
  Timer? _barrioDebounce;

  /// Suscripción al stream de GPS: mantiene la ubicación viva mientras
  /// la app está abierta (antes solo se tomaba un fix al iniciar).
  StreamSubscription<Position>? _gpsStreamSub;

  /// Modo manual: el GPS falló y el usuario escribe su dirección.
  bool _manualMode = false;

  /// El usuario tocó/escribió el origen: el GPS ya no debe sobrescribirlo.
  bool _originEditedByUser = false;

  bool _activeServiceCheckInFlight = false;
  int? _viajeActivoId;

  bool get _isExpanded => _sheetVisualState != _SheetVisualState.compact;

  bool get _hasOrigin => _selectedOrigin != null;

  bool get _hasDestination => _selectedDestination != null;

  bool get _hasRoute => _routeInfo != null;

  bool get _needsRouteRetry =>
      _serviceType != 'taxi' && _hasOrigin && _hasDestination && !_hasRoute;

  bool get _canRequestRide {
    if (!_hasOrigin || !_pickupPin.gpsListo) return false;
    if (!_pinCanContinue(_pickupPin)) {
      return false;
    }
    if (_serviceType != 'taxi') {
      return _hasDestination &&
          _hasRoute &&
          _pinCanContinue(_destPin);
    }
    return _pinCanContinue(_destPin);
  }

  bool _pinCanContinue(ServicePin? pin) {
    if (pin == null) return true;
    if (pin.necesitaElegirBarrio && !pin.barrioPorConfirmar) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placesSearch = PasajeroPlacesSearchController(placesService: _placesService);
    _createUserMarkerIcon();
    unawaited(_nearbyDrivers.loadDriverMarkerIcon().then((_) {
      if (mounted) _setStateSafe(() {});
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_createDestinationPointIcon());
    });
    unawaited(_setupSocketConductores());
    _setupSocketOffers();
    _setupSocketRequestConfirmation();
    unawaited(_checkActiveService());
    _initializeLocation();

    // Listeners
    _originController.addListener(_onOriginChanged);
    _destinationController.addListener(_onDestinationChanged);
    RepeatTripService.instance.addListener(_onRepeatTripRequested);
    _sheetController.addListener(_onSheetControllerChanged);
    _driverMarkersTicker = createTicker(_onDriverMarkersTick)..start();
  }

  void _ensureMarkerTickerRunning() {
    if (_isDisposed || !mounted) return;
    _idleMarkerTicks = 0;
    final ticker = _driverMarkersTicker;
    if (ticker != null && !ticker.isActive) {
      ticker.start();
    }
  }

  void _onDriverMarkersTick(Duration elapsed) {
    if (!mounted || _isDisposed) return;
    if (_nearbyDrivers.tickMarkerAnimation(showDrivers: _showDrivers)) {
      _idleMarkerTicks = 0;
      _syncMarkersOnMap();
    } else {
      _idleMarkerTicks++;
      if (_idleMarkerTicks >= 3) {
        _driverMarkersTicker?.stop();
      }
    }
  }

  void _startDriversRefreshTimer() {
    _driversRefreshTimer?.cancel();
    final interval = _nearbyDrivers.socketConnected
        ? RuntimePerfFlags.driversApiRefreshWithSocket
        : RuntimePerfFlags.driversApiRefreshWithoutSocket;
    _driversRefreshTimer = Timer.periodic(
      interval,
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onAppResumed());
    }
  }

  /// Al volver del background: servicio activo (si lo hay), GPS vivo y
  /// conductores cercanos frescos.
  Future<void> _onAppResumed() async {
    if (!mounted || _isDisposed) return;

    unawaited(_checkActiveService());
    unawaited(_loadAvailableDrivers(silent: true, force: true));

    if (_currentPosition == null) {
      await _initializeLocation();
      return;
    }

    _startGpsStream();
    unawaited(_refreshPositionOnce());
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _gpsStreamSub?.cancel();
    _gpsStreamSub = null;

    _activeServiceController.dispose();

    // Limpiar referencia al ScaffoldMessenger
    _scaffoldMessenger = null;

    _socketOffers.unsubscribeAll(
      includeGlobalOffers: _enableGlobalOffersChannel,
    );
    _placesSearch.dispose();

    // Remover listeners de los controladores de texto ANTES de disponer
    _originController.removeListener(_onOriginChanged);
    _destinationController.removeListener(_onDestinationChanged);
    RepeatTripService.instance.removeListener(_onRepeatTripRequested);

    _nearbyDrivers.dispose();

    _mapController?.dispose();
    _sheetController.removeListener(_onSheetControllerChanged);
    _sheetController.dispose();
    _sheetExtent.dispose();
    _driverMarkersTicker?.dispose();
    _driversRefreshTimer?.cancel();
    _barrioDebounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
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
        _originEditedByUser = true;
        _namedPickupLocked = !origin.isCurrentLocation;
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
      await _drawRoute();
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

  Future<void> _checkActiveService() async {
    if (_activeServiceCheckInFlight) return;
    _activeServiceCheckInFlight = true;
    try {
      final servicio = await _activeServiceController.fetchActiveServiceIfAny();
      if (!mounted) return;
      if (servicio == null) {
        if (_viajeActivoId != null) {
          _setStateSafe(() => _viajeActivoId = null);
        }
        return;
      }

      _setStateSafe(() => _viajeActivoId = servicio.id);

      // Solo se omite si ESA pantalla ya está encima. Un registro viejo
      // no puede dejar al pasajero atrapado en el home.
      if (ActiveServiceScreenRegistry.isShowing(
        type: 'pasajero',
        serviceId: servicio.id,
      )) {
        return;
      }

      await _abrirViajeActivo(servicio);
    } finally {
      _activeServiceCheckInFlight = false;
    }
  }

  Future<void> _entrarAlViajeActivo() async {
    final servicio = await _activeServiceController.fetchActiveServiceIfAny();
    if (servicio == null || !mounted) {
      if (mounted) _setStateSafe(() => _viajeActivoId = null);
      return;
    }
    _setStateSafe(() => _viajeActivoId = servicio.id);
    await _abrirViajeActivo(servicio);
  }

  Future<void> _abrirViajeActivo(ServicioActivo servicio) async {
    if (!mounted) return;
    final raw = Map<String, dynamic>.from(servicio.toJson());
    final datos = ServicioPayloadAdapter.normalize(
      servicio: raw,
      conductor: servicio.conductor != null
          ? {
              'id': servicio.conductor!.id,
              'nombre': servicio.conductor!.nombre,
              'telefono': servicio.conductor!.telefono,
              'foto': servicio.conductor!.foto,
              'calificacion': servicio.conductor!.calificacion,
              'lat': servicio.conductor!.lat,
              'lng': servicio.conductor!.lng,
            }
          : null,
      vehiculo: servicio.vehiculo != null
          ? {
              'marca': servicio.vehiculo!.marca,
              'modelo': servicio.vehiculo!.modelo,
              'placa': servicio.vehiculo!.placa,
              'color': servicio.vehiculo!.color,
            }
          : null,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasajeroEsperandoConductorScreen(
          servicioId: servicio.id,
          datosServicio: datos,
        ),
      ),
    );
  }

  // ========== MÉTODOS DE CONDUCTORES DISPONIBLES ==========

  Future<void> _setupSocketConductores() async {
    await _nearbyDrivers.connectSocket(
      onDriverUpdate: (conductor) {
        if (!mounted) return;
        _ensureMarkerTickerRunning();
        _nearbyDrivers.applyDriverUpdate(
          conductor,
          showDrivers: _showDrivers,
        );
        if (_nearbyDrivers.displayedPositions.containsKey(
          conductor.conductorId,
        )) {
          _syncMarkersOnMap();
        }
      },
      onDriverOffline: (conductorId) {
        if (!mounted) return;
        _ensureMarkerTickerRunning();
        _nearbyDrivers.removeDriver(conductorId);
        _syncMarkersOnMap(force: true);
      },
    );
  }

  Future<void> _loadAvailableDrivers({
    bool silent = false,
    bool force = false,
  }) async {
    if (_currentPosition == null) return;
    await _nearbyDrivers.loadFromApi(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      silent: silent,
      force: force,
    );
    if (mounted) _syncMarkersOnMap(force: true);
  }

  /// Recompone marcadores del mapa (conductores animados + ruta + resto).
  InfoWindow _userLocationInfoWindow() {
    return InfoWindow(
      title: _currentLocationName,
      snippet: _currentLocationAddress != _currentLocationName
          ? _currentLocationAddress
          : '',
    );
  }

  String get _originPickupLabel => _currentLocationName;

  /// Barrio como detalle secundario cuando la etiqueta principal es la calle.
  String? get _pickupOriginDetail {
    final origin = _selectedOrigin;
    if (origin != null && !origin.isCurrentLocation) {
      // Origen escrito por el usuario: detalle con su dirección (sin ciudad).
      final detail = SolicitudDisplayHelper.routeAddressSubtitle(
        origin.address,
      );
      if (detail.isEmpty || detail.toLowerCase() == origin.name.toLowerCase()) {
        return null;
      }
      return detail;
    }

    final barrio = _currentLocationArea?.trim();
    if (barrio == null || barrio.isEmpty) return null;
    if (_currentLocationName.toLowerCase().contains(barrio.toLowerCase())) {
      return null;
    }
    return barrio;
  }

  String _passengerOriginLabelFrom(CurrentLocationData data) {
    final street = data.streetLine?.trim();
    if (street != null && street.isNotEmpty) {
      final line = SolicitudDisplayHelper.streetLineSinCiudad(street);
      if (line.isNotEmpty) return line;
    }
    final addr = data.address.trim();
    if (addr.isNotEmpty &&
        addr != 'Ubicación actual' &&
        addr != 'Mi ubicación actual') {
      final compact = SolicitudDisplayHelper.routeAddressSubtitle(addr);
      if (compact.isNotEmpty) return compact;
      final first = addr.split(',').first.trim();
      if (first.length >= 3) return first;
    }
    final name = data.name.trim();
    if (name.isNotEmpty && name != 'Mi ubicación') return name;
    return 'Mi ubicación';
  }

  String get _pickupDisplayLabel {
    final origin = _selectedOrigin;
    if (origin == null) return _originPickupLabel;
    // Origen vivo del GPS: usar la etiqueta actualizada (cambia con el refine).
    if (origin.isCurrentLocation) return _originPickupLabel;
    return origin.name;
  }

  void _syncMarkersOnMap({bool force = false}) {
    if (!mounted || _isDisposed) return;

    if (!force) {
      final now = DateTime.now();
      final last = _lastMarkerSyncAt;
      if (last != null &&
          now.difference(last) < RuntimePerfFlags.markerSyncMinInterval) {
        return;
      }
      _lastMarkerSyncAt = now;
    }

    final newMarkers = <Marker>{
      ..._nearbyDrivers.buildDriverMarkers(
        showDrivers: _showDrivers,
        onTap: _onDriverMarkerTap,
      ),
    };

    if (_routeInfo != null &&
        _selectedOrigin != null &&
        _selectedDestination != null) {
      final originLatLng = LatLng(_selectedOrigin!.lat, _selectedOrigin!.lng);
      final destinationLatLng = LatLng(
        _selectedDestination!.lat,
        _selectedDestination!.lng,
      );
      final isOriginCurrentLocation = _selectedOrigin!.isCurrentLocation;

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
            title: isOriginCurrentLocation
                ? (_currentLocationArea ?? 'Tu ubicación')
                : 'Origen',
            snippet: isOriginCurrentLocation
                ? (_currentLocationStreet ?? _selectedOrigin!.name)
                : _selectedOrigin!.name,
          ),
        ),
      );
      newMarkers.add(
        _buildDestinationMarker(
          destinationLatLng,
          _selectedDestination!.name,
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

      // Recogida elegida a mano (sin ruta dibujada): se pinta su pin.
      final origin = _selectedOrigin;
      if (origin != null &&
          !origin.isCurrentLocation &&
          origin.lat.isFinite &&
          origin.lng.isFinite) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: LatLng(origin.lat, origin.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Recogida',
              snippet: origin.name,
            ),
          ),
        );
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
            infoWindow: _userLocationInfoWindow(),
            zIndexInt: 10,
          ),
        );
      }
    }

    _setStateSafe(() => _markers = newMarkers);
  }

  void _updateAllDriverMarkers() => _syncMarkersOnMap();

  /// Crea un icono tipo punto para destino (sin usar pines por defecto de Google)
  Future<void> _createDestinationPointIcon() async {
    try {
      final icon = await MapDotMarkerFactory.create(
        color: Colors.black,
        size: 28,
      );
      _setStateSafe(() => _destinationPointIcon = icon);
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
                  onRetry: _handleLocationRecovery,
                  actionLabel: _locationActionLabel,
                  actionIcon: _locationActionIcon,
                  secondaryActionLabel: 'Escribir mi dirección',
                  onSecondaryAction: _enterManualLocationMode,
                ),
              )
            : RepaintBoundary(
                child: StandardMap(
                  initialPosition: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  zoom: _mapZoomPasajero,
                  tilt: _mapTiltPasajero,
                  bearing: _mapBearingPasajero,
                  buildingsEnabled: false,
                  tiltGesturesEnabled: false,
                  polylines: _polylines,
                  markers: _markers,
                  mapPadding: EdgeInsets.only(
                    bottom: MediaQuery.sizeOf(context).height * _sheetMidSize,
                  ),
                  onTap: _onMapTap,
                  onCameraMoveStarted: () {
                    if (_cameraOwnedByApp || _puntosBloqueados) return;
                    _setStateSafe(() {
                      _mapMoving = true;
                      _namedPickupLocked = false;
                      _pickupPin.origen = PinOrigen.ajusteManual;
                      _originEditedByUser = true;
                    });
                  },
                  onCameraMove: (pos) => _lastCameraTarget = pos.target,
                  onCameraIdle: _onPickupCameraIdle,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),

        if (_currentPosition != null)
          Positioned(
            key: const ValueKey('center-pin'),
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.sizeOf(context).height * _sheetMidSize,
            child: IgnorePointer(
              child: Opacity(
                opacity: _showCenterPin ? 1 : 0,
                child: Center(child: MapCenterPin(moving: _mapMoving)),
              ),
            ),
          ),

        // Overlay del mapa: solo escucha el extent, sin rebuild del árbol completo.
        if (_currentPosition != null)
          Positioned.fill(
            key: const ValueKey('map-dim'),
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

        if (_viajeActivoId != null)
          Positioned(
            key: const ValueKey('active-trip'),
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => unawaited(_entrarAlViajeActivo()),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.local_taxi, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tienes un viaje en curso. Toca para entrar.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Bottom sheet de viaje: un solo scroll continuo (sin saltos de layout).
        if (_currentPosition != null)
          Positioned.fill(
            key: const ValueKey('ride-sheet'),
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _sheetMidSize,
              minChildSize: _sheetMinSize,
              maxChildSize: _sheetMaxSize,
              expand: false,
              snap: true,
              snapAnimationDuration: const Duration(milliseconds: 320),
              snapSizes: const [_sheetMinSize, _sheetMidSize, _sheetMaxSize],
              builder: (context, scrollController) {
                final cta = _requestCtaState();
                return PasajeroHomeRideSheet(
                  scrollController: scrollController,
                  serviceType: _serviceType,
                  pickupDisplayLabel: _pickupDisplayLabel,
                  pickupStreetDetail: _pickupOriginDetail,
                  originController: _originController,
                  destinationController: _destinationController,
                  originFocusNode: _originFocusNode,
                  destinationFocusNode: _destinationFocusNode,
                  originPredictions: _originPredictions,
                  destinationPredictions: _destinationPredictions,
                  isSearchingOrigin: _isSearchingOrigin,
                  isSearchingDestination: _isSearchingDestination,
                  onToggleSheet: _toggleSheet,
                  onServiceTypeChanged: (type) {
                    _setStateSafe(() {
                      _serviceType = type;
                      _clearRoute();
                    });
                  },
                  onSelectOrigin: (prediction) async {
                    await _selectOrigin(prediction);
                    _setStateSafe(() => _editingPickup = false);
                  },
                  onSelectDestination: _selectDestination,
                  onClearOrigin: _restoreGpsPickup,
                  onClearDestination: () {
                    _setStateSafe(() {
                      _destinationController.clear();
                      _selectedDestination = null;
                      _selectedDestinationArea = null;
                      _destinationPredictions = [];
                      _clearRoute();
                    });
                  },
                  editingPickup: _editingPickup,
                  onEditPickup: _startEditingPickup,
                  locatingGps: !_pickupPin.gpsListo,
                  ctaLabel: cta.label,
                  ctaTrailing: cta.trailing,
                  onCtaPressed: cta.onPressed,
                  ctaLoading: cta.isLoading,
                  ctaColor: cta.color,
                );
              },
            ),
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

  ({
    String label,
    String? trailing,
    VoidCallback? onPressed,
    bool isLoading,
    Color color,
  }) _requestCtaState() {
    final isLoading = _isSubmittingRide ||
        (_isDrawingRoute && _serviceType != 'taxi');
    final eta = _nearbyDrivers.nearestEtaMinutes(
      fromLat: _currentPosition?.latitude,
      fromLng: _currentPosition?.longitude,
    );
    final etaText = eta == null ? null : 'Llega en ~$eta min';

    if (_needsRouteRetry) {
      return (
        label: _isDrawingRoute ? 'Calculando ruta...' : 'Calcular ruta',
        trailing: null,
        onPressed: isLoading ? null : _drawRoute,
        isLoading: isLoading,
        color: Colors.deepOrange,
      );
    }
    if (_canRequestRide) {
      return (
        label: _isSubmittingRide
            ? 'Buscando conductor...'
            : (_serviceType == 'taxi'
                ? 'Pedir taxi ahora'
                : 'Pedir domicilio ahora'),
        trailing: _isSubmittingRide ? null : etaText,
        onPressed: isLoading ? null : _requestRide,
        isLoading: isLoading,
        color: _serviceType == 'taxi'
            ? AppColors.primary
            : Colors.orange.shade600,
      );
    }
    return (
      label: _serviceType == 'taxi'
          ? 'Pedir taxi ahora'
          : 'Elige origen y destino',
      trailing: etaText,
      onPressed: _hasOrigin ? _requestRide : null,
      isLoading: isLoading,
      color: _hasOrigin ? AppColors.primary : Colors.grey,
    );
  }

  void _startEditingPickup() {
    _originController.removeListener(_onOriginChanged);
    _originController.clear();
    _originController.addListener(_onOriginChanged);
    _setStateSafe(() {
      _editingPickup = true;
      _originEditedByUser = true;
      _originPredictions = [];
      _isSearchingOrigin = false;
    });
    unawaited(_focusPickupEditor());
  }

  Future<void> _focusPickupEditor() async {
    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        _sheetMaxSize,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted || _isDisposed) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || _isDisposed) return;
    _originFocusNode.requestFocus();
    final ctx = _originFocusNode.context;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.05,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _restoreGpsPickup() {
    final position = _currentPosition;
    FocusScope.of(context).unfocus();
    _setStateSafe(() {
      _editingPickup = false;
      _originPredictions = [];
      _isSearchingOrigin = false;
      _originEditedByUser = false;
      _namedPickupLocked = false;
    });
    if (position != null) {
      _selectedOrigin = null;
      _pickupPin
        ..lat = position.latitude
        ..lng = position.longitude
        ..origen = PinOrigen.gps
        ..elegido = null
        ..confirmadoPorUsuario = false;
      _applyOriginFromGps(position, markReady: true);
      _schedulePickupBarrioResolve();
      unawaited(_refineOriginAddress(position));
    }
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

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final imageData = response.bodyBytes;
      if (imageData.isEmpty) return null;

      final decoded = await decodeImageFromBytes(
        imageData,
        targetWidth: markerSize.toInt(),
        targetHeight: markerSize.toInt(),
      );
      if (decoded == null) return null;

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
        decoded,
        Rect.fromLTWH(
          0,
          0,
          decoded.width.toDouble(),
          decoded.height.toDouble(),
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

  void _setLocationFailure({
    required bool serviceEnabled,
    required PermissionStatus permission,
    String? overrideMessage,
  }) {
    _isLoadingLocation = false;
    _locationMessage = overrideMessage ??
        DeviceLocationService.messageForFailure(
          serviceEnabled: serviceEnabled,
          permission: permission,
        );
    _locationNeedsSettings = DeviceLocationService.needsSettingsRecovery(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
    _locationActionLabel = DeviceLocationService.actionLabelForFailure(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
    _locationActionIcon = _locationNeedsSettings
        ? Icons.settings_rounded
        : Icons.refresh_rounded;
  }

  Future<void> _handleLocationRecovery() async {
    // Escape durante loading: detiene el spinner para que el usuario pueda
    // reintentar o abrir ajustes sin quedar atrapado.
    if (_isLoadingLocation) {
      _setStateSafe(() {
        _isLoadingLocation = false;
        _locationMessage =
            'El GPS tardó demasiado. Toca reintentar para continuar.';
        _locationActionLabel = 'Reintentar ubicación';
        _locationActionIcon = Icons.refresh_rounded;
        _locationNeedsSettings = false;
      });
      return;
    }

    final serviceEnabled = await DeviceLocationService.isServiceEnabled();
    final permission = await DeviceLocationService.locationPermissionStatus();

    if (DeviceLocationService.needsSettingsRecovery(
      serviceEnabled: serviceEnabled,
      permission: permission,
    )) {
      _setStateSafe(() {
        _setLocationFailure(
          serviceEnabled: serviceEnabled,
          permission: permission,
        );
      });
      await DeviceLocationService.openRecoverySettings(
        serviceEnabled: serviceEnabled,
        permission: permission,
      );
      return;
    }

    await _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    _setStateSafe(() {
      _isLoadingLocation = true;
      _manualMode = false;
      _locationNeedsSettings = false;
      _locationActionLabel = 'Reintentar ubicación';
      _locationActionIcon = Icons.refresh_rounded;
      _locationMessage = 'Verificando permisos...';
    });

    try {
      await _initializeLocationBody()
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      AppLogger.w('Timeout inicializando ubicación pasajero', tag: 'HomePasajero');
      if (!mounted) return;
      final serviceEnabled = await DeviceLocationService.isServiceEnabled();
      final permission = await DeviceLocationService.locationPermissionStatus();
      _setStateSafe(() {
        _setLocationFailure(
          serviceEnabled: serviceEnabled,
          permission: permission,
          overrideMessage:
              'El GPS tardó demasiado. Toca reintentar para continuar.',
        );
      });
    }
  }

  Future<void> _initializeLocationBody() async {
    if (!await DeviceLocationService.isServiceEnabled()) {
      final permission =
          await DeviceLocationService.locationPermissionStatus();
      _setStateSafe(() {
        _setLocationFailure(
          serviceEnabled: false,
          permission: permission,
        );
      });
      return;
    }

    final permissionGranted =
        await DeviceLocationService.requestLocationPermission();
    final permission = await DeviceLocationService.locationPermissionStatus();

    if (!permissionGranted) {
      _setStateSafe(() {
        _setLocationFailure(
          serviceEnabled: true,
          permission: permission,
        );
      });
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _setStateSafe(() => _locationMessage = 'Obteniendo ubicación...');

      final result = await DeviceLocationService.resolveCurrentPosition();
      if (result == null || !mounted) {
        if (!mounted) return;
        final permission =
            await DeviceLocationService.locationPermissionStatus();
        _setStateSafe(() {
          _setLocationFailure(
            serviceEnabled: true,
            permission: permission,
          );
        });
        return;
      }

      final position = result.position;

      if (result.usedDebugFallback && mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Modo desarrollo: ubicación simulada en el centro de Popayán.',
            ),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _setStateSafe(() {
        _currentPosition = position;
        _locationMessage = 'Obteniendo dirección...';
      });

      // Ancla de la búsqueda: los lugares se ordenan por cercanía a este punto.
      _placesService.updateSearchContext(
        lat: position.latitude,
        lng: position.longitude,
      );

      _rawGpsPosition = position;
      await _refineOriginAddress(position);

      if (!mounted) return;

      _applyOriginFromGps(position, markReady: true);
      _startGpsStream();

      unawaited(
        _animateCameraTo(position.latitude, position.longitude),
      );

      unawaited(_loadAvailableDrivers(force: true));
      _startDriversRefreshTimer();
      unawaited(_requestNotificationPermissionAfterLocation());
      _tryApplyPendingRepeatTrip();
    } catch (e) {
      AppLogger.e('Error GPS pasajero', tag: 'HomePasajero', error: e);
      if (mounted) {
        final permission =
            await DeviceLocationService.locationPermissionStatus();
        _setStateSafe(() {
          _setLocationFailure(
            serviceEnabled: true,
            permission: permission,
          );
        });
      }
    }
  }

  /// El origen no debe ser tocado por el GPS: el usuario lo eligió
  /// manualmente o lo está escribiendo en el campo.
  bool get _originLockedByUser =>
      _namedPickupLocked ||
      _editingPickup ||
      _originEditedByUser ||
      (_selectedOrigin != null && !_selectedOrigin!.isCurrentLocation);

  bool get _cameraOwnedByApp => _programmaticCamera;

  /// Recogida y destino ya elegidos: arrastrar el mapa solo lo mueve,
  /// no cambia el marcador.
  bool get _puntosBloqueados => _hasOrigin && _hasDestination;

  /// El pin del centro solo sirve para colocar la recogida. Con una
  /// dirección ya elegida, o con la ruta en pantalla, el punto queda en
  /// su marcador y la cámara puede moverse sin llevárselo.
  bool get _showCenterPin {
    if (_puntosBloqueados) return false;
    if (_mapMoving && !_cameraOwnedByApp) return true;
    if (_routeInfo != null || _namedPickupLocked) return false;
    final origin = _selectedOrigin;
    if (_pickupPin.origen == PinOrigen.ajusteManual &&
        origin != null &&
        !origin.isCurrentLocation) {
      return false;
    }
    return true;
  }

  /// Mantiene la ubicación actualizándose sola mientras la app está abierta.
  void _startGpsStream() {
    if (_gpsStreamSub != null || _isDisposed) return;
    _gpsStreamSub = Geolocator.getPositionStream(
      locationSettings: PreciseGps.stream(
        use: PreciseGpsUse.pickup,
        distanceFilter: 2,
      ),
    ).listen(
      _onGpsStreamPosition,
      onError: (Object e) {
        AppLogger.w('Stream GPS pasajero: $e', tag: 'HomePasajero');
      },
      cancelOnError: false,
    );
  }

  /// Fix puntual al volver del background (el stream puede haber muerto).
  Future<void> _refreshPositionOnce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: PreciseGps.currentPosition(
          timeLimit: const Duration(seconds: 10),
          use: PreciseGpsUse.pickup,
        ),
      ).timeout(const Duration(seconds: 12));
      if (!mounted || _isDisposed) return;
      _onGpsStreamPosition(position);
    } catch (e) {
      AppLogger.d('Refresh GPS pasajero: $e', tag: 'HomePasajero');
    }
  }

  void _onGpsStreamPosition(Position position) {
    if (!mounted || _isDisposed) return;
    if (!PreciseGps.shouldAccept(position, _rawGpsPosition)) return;
    _rawGpsPosition = position;
    final shown = position;

    // La búsqueda de lugares se ordena por cercanía a este punto.
    _placesService.updateSearchContext(
      lat: shown.latitude,
      lng: shown.longitude,
    );

    // GPS recuperado y el usuario aún no escribió nada → modo manual caduca.
    if (_manualMode &&
        _selectedOrigin == null &&
        _originController.text.trim().isEmpty) {
      _setStateSafe(() => _manualMode = false);
    }

    _applyOriginFromGps(shown, markReady: _currentPosition == null);
    if (_pickupPin.origen == PinOrigen.gps) {
      _pickupPin
        ..lat = shown.latitude
        ..lng = shown.longitude
        ..precisionGpsM = position.accuracy;
      unawaited(_animateCameraTo(shown.latitude, shown.longitude));
      _schedulePickupBarrioResolve();
    }
    _syncMarkersOnMap(force: true);
  }

  /// El usuario pide escribir su ubicación a mano porque el GPS falló.
  Future<void> _enterManualLocationMode() async {
    if (!mounted || _isDisposed) return;

    var lat = PopayanUrbanArea.centerLat;
    var lng = PopayanUrbanArea.centerLng;
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        lat = lastKnown.latitude;
        lng = lastKnown.longitude;
      }
    } catch (_) {
      // Sin última ubicación conocida: se usa el centro urbano.
    }

    if (!mounted || _isDisposed) return;

    _setStateSafe(() {
      _manualMode = true;
      _isLoadingLocation = false;
      _locationNeedsSettings = false;
      _locationMessage =
          'Modo manual: escribe tu dirección de recogida en el formulario.';
      _locationActionLabel = 'Reintentar ubicación';
      _locationActionIcon = Icons.refresh_rounded;
      _currentPosition = _positionAt(lat, lng);
      _currentLocationName = 'Escribe tu dirección';
      _currentLocationAddress = 'Ingresa la recogida manualmente';
      _currentLocationArea = null;
      _currentLocationStreet = null;
      _selectedOrigin = null;
      _originEditedByUser = false;
      _originController.removeListener(_onOriginChanged);
      _originController.text = '';
      _originController.addListener(_onOriginChanged);
    });

    _startGpsStream();
    unawaited(_loadAvailableDrivers(force: true));

    if (_sheetController.isAttached) {
      unawaited(
        _sheetController.animateTo(
          _sheetMidSize,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Position _positionAt(double lat, double lng) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 25,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  void _applyOriginFromGps(Position position, {required bool markReady}) {
    final lockOrigin = _originLockedByUser;
    _setStateSafe(() {
      _currentPosition = position;
      if (markReady) {
        _isLoadingLocation = false;
        _locationMessage = 'Listo para pedir servicio';
      }

      // El usuario definió su recogida a mano: solo se actualiza la posición,
      // nunca su origen ni el texto del campo.
      if (!lockOrigin) {
        _selectedOrigin = _tripFromPickupPin(
          lat: position.latitude,
          lng: position.longitude,
        );

        if (_originController.text.trim().isEmpty ||
            _selectedOrigin?.isCurrentLocation == true) {
          _originController.removeListener(_onOriginChanged);
          _originController.text = _currentLocationName;
          _originController.addListener(_onOriginChanged);
        }
      }

      if (_markers.isEmpty && _userMarkerIcon != null) {
        _markers = {
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(position.latitude, position.longitude),
            icon: _userMarkerIcon!,
            infoWindow: _userLocationInfoWindow(),
          ),
        };
      }
    });
  }

  Future<void> _refineOriginAddress(Position position) async {
    try {
      final locationData = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;

      final resolvedLabel = _passengerOriginLabelFrom(locationData);
      final needsPoiLookup = resolvedLabel == 'Mi ubicación' ||
          !SolicitudDisplayHelper.looksLikeStreetAddress(resolvedLabel);

      PlaceResult? nearby;
      if (needsPoiLookup) {
        nearby = await _placesService.findNearestPlaceAt(
          position.latitude,
          position.longitude,
          maxDistanceMeters: PreciseGps.maxPickupAccuracyMeters,
        );
      }
      if (!mounted) return;

      final poiName = nearby?.name.trim();
      final usePoiName = poiName != null &&
          poiName.isNotEmpty &&
          !SolicitudDisplayHelper.looksLikeStreetAddress(poiName);

      final lockOrigin = _originLockedByUser;
      _setStateSafe(() {
        // Geocoder y Places mejoran las etiquetas; el punto sigue siendo el
        // GPS recibido, sin desplazarlo a las coordenadas de una vía cercana.
        _currentPosition = position;
        _currentLocationName = usePoiName
            ? poiName
            : _passengerOriginLabelFrom(locationData);
        _currentLocationArea = locationData.area;
        _currentLocationStreet = locationData.streetLine;
        _currentLocationAddress = nearby?.address.trim().isNotEmpty == true
            ? nearby!.address
            : locationData.address;

        if (!lockOrigin) {
          _selectedOrigin = TripLocation(
            placeId: nearby?.placeId,
            name: _currentLocationName,
            address: _currentLocationAddress,
            lat: position.latitude,
            lng: position.longitude,
            isCurrentLocation: true,
          );
          _originController.removeListener(_onOriginChanged);
          _originController.text = _currentLocationName;
          _originController.addListener(_onOriginChanged);
        }

        _syncMarkersOnMap();
      });
    } catch (e) {
      AppLogger.d('No se pudo refinar la etiqueta del origen: $e');
    }
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

  Future<void> _expandSheet({bool focusDestination = true}) async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      _sheetMidSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    if (focusDestination && !_editingPickup) {
      _destinationFocusNode.requestFocus();
    }
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

  Future<void> _onMapTap(LatLng latLng) async {
    if (_buscandoPunto) return;
    await _setDestinationFromMap(latLng);
  }

  Future<void> _setDestinationFromMap(LatLng latLng) async {
    if (_isResolvingMapDestination || _isSubmittingRide) return;

    if (!PopayanUrbanArea.contains(latLng.latitude, latLng.longitude)) {
      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text(PopayanUrbanArea.searchNotice),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Espera a que cargue tu ubicación'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _setStateSafe(() => _isResolvingMapDestination = true);

    try {
      if (_selectedOrigin == null) {
        _applyOriginFromGps(_currentPosition!, markReady: false);
      }

      final nearby = await _placesService.findNearestPlaceAt(
        latLng.latitude,
        latLng.longitude,
      );

      late final TripLocation destination;
      if (nearby != null) {
        destination = TripLocation.fromPlaceDetails(
          placeId: nearby.placeId,
          name: nearby.name,
          address: nearby.address,
          lat: nearby.lat,
          lng: nearby.lng,
        );
      } else {
        final label = await _reverseGeocodingService.resolveMapDestinationLabel(
          lat: latLng.latitude,
          lng: latLng.longitude,
        );
        destination = TripLocation(
          name: label.name,
          address: label.address,
          lat: latLng.latitude,
          lng: latLng.longitude,
        );
      }

      if (!mounted) return;

      await _applyDestinationLocation(destination);

      if (!mounted) return;
      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text('Destino: ${destination.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      AppLogger.w('No se pudo fijar destino en mapa: $e');
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(
            content: Text('No se pudo usar ese punto. Intenta de nuevo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        _setStateSafe(() => _isResolvingMapDestination = false);
      }
    }
  }

  Marker _buildDestinationMarker(
    LatLng position,
    String title,
    String snippet,
  ) {
    return Marker(
      markerId: const MarkerId('destination'),
      position: position,
      icon:
          _destinationPointIcon ??
          _nearbyDrivers.driverMarkerIcon ??
          BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(title: title, snippet: snippet),
      draggable: false,
      // onDragEnd: _onDestinationMarkerDragged,
      zIndexInt: 6,
    );
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
        destination.name,
        _destinationMarkerSnippet(destination),
      ),
    );
    _markers = nextMarkers;
  }

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

      TripLocation? home;
      TripLocation? work;
      try {
        final homeRaw = prefs.getString(_prefKey('home'));
        final workRaw = prefs.getString(_prefKey('work'));
        if (homeRaw != null && homeRaw.isNotEmpty) {
          home = _tripLocationFromMap(
            (jsonDecode(homeRaw) as Map).cast<String, dynamic>(),
          );
        }
        if (workRaw != null && workRaw.isNotEmpty) {
          work = _tripLocationFromMap(
            (jsonDecode(workRaw) as Map).cast<String, dynamic>(),
          );
        }
      } catch (_) {}

      if (!mounted) return;
      _setStateSafe(() {
        _recentDestinations = recent;
        _favoriteHome = home;
        _favoriteWork = work;
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
      _setStateSafe(() {
        if (type == 'home') {
          _favoriteHome = selected;
        } else {
          _favoriteWork = selected;
        }
      });
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
    unawaited(_resolveDestBarrio(destination.lat, destination.lng));
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

  /// Ajusta la altura de la hoja para que la lista de sugerencias quede
  /// visible sobre el teclado.
  ///
  /// Con la hoja a la mitad, la lista se dibuja detrás del teclado y el
  /// usuario escribe sin ver nada: parecía que la búsqueda no encontraba
  /// destinos. Al aparecer sugerencias la hoja sube; al desaparecer,
  /// vuelve a su tamaño normal.
  Future<void> _ajustarHojaParaSugerencias(bool haySugerencias) async {
    if (!_sheetController.isAttached || !mounted) return;
    final actual = _sheetController.size;
    if (haySugerencias) {
      if (actual < _sheetMaxSize - 0.02) {
        await _sheetController.animateTo(
          _sheetMaxSize,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (actual > _sheetMidSize + 0.02 && actual < _sheetMaxSize - 0.02) {
      await _sheetController.animateTo(
        _sheetMidSize,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onOriginChanged() {
    if (!mounted) return;
    _originEditedByUser = true;
    _hidePolyline();
    final query = _originController.text.trim();
    _placesSearch.clearSessionIfBothEmpty(
      originQuery: query,
      destinationQuery: _destinationController.text.trim(),
    );
    _placesSearch.searchOrigin(
      query: query,
      onResult: (predictions, searching) {
        if (!mounted) return;
        _setStateSafe(() {
          _originPredictions = predictions;
          _isSearchingOrigin = searching;
        });
        unawaited(_ajustarHojaParaSugerencias(predictions.isNotEmpty));
      },
    );
  }

  void _onDestinationChanged() {
    if (!mounted) return;
    _hidePolyline();
    final query = _destinationController.text.trim();
    _placesSearch.clearSessionIfBothEmpty(
      originQuery: _originController.text.trim(),
      destinationQuery: query,
    );
    _placesSearch.searchDestination(
      query: query,
      onResult: (predictions, searching) {
        if (!mounted) return;
        _setStateSafe(() {
          _destinationPredictions = predictions;
          _isSearchingDestination = searching;
        });
        unawaited(_ajustarHojaParaSugerencias(predictions.isNotEmpty));
      },
    );
  }

  Future<void> _selectOrigin(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _originController.removeListener(_onOriginChanged);
    _placesSearch.cancelOriginSearch();

    final details = await _placesSearch.resolvePlace(prediction);

    if (!mounted) return;

    if (details == null) {
      _originController.addListener(_onOriginChanged);
      _setStateSafe(() {
        _originPredictions = [];
        _isSearchingOrigin = false;
      });
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos ubicar esa recogida en Popayán. Prueba otra sugerencia.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _pickupPin
      ..lat = details.lat
      ..lng = details.lng
      ..origen = PinOrigen.ajusteManual
      ..resolve = null
      ..elegido = null
      ..confirmadoPorUsuario = false;

    final placeName = details.name.trim().isNotEmpty
        ? details.name.trim()
        : prediction.mainText;
    final placeAddress = details.address.trim().isNotEmpty
        ? details.address.trim()
        : prediction.description;
    _originController.text = placeName;
    _originController.addListener(_onOriginChanged);
    _setStateSafe(() {
      _selectedOrigin = TripLocation(
        placeId: prediction.placeId,
        name: placeName,
        address: placeAddress,
        lat: details.lat,
        lng: details.lng,
        isCurrentLocation: false,
      );
      _currentLocationName = placeName;
      _currentLocationAddress = placeAddress;
      _originEditedByUser = true;
      _namedPickupLocked = true;
      _originPredictions = [];
      _isSearchingOrigin = false;
      _editingPickup = false;
    });
    _syncMarkersOnMap(force: true);
    unawaited(_animateCameraTo(details.lat, details.lng));
    unawaited(_resolvePickupBarrio());
    unawaited(_ajustarHojaParaSugerencias(false));

    if (_selectedDestination != null) {
      await _drawRoute();
    }
  }

  Future<void> _selectDestination(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _destinationController.removeListener(_onDestinationChanged);
    _placesSearch.cancelDestinationSearch();

    final details = await _placesSearch.resolvePlace(
      prediction,
      preferNearby: false,
    );

    if (!mounted) return;

    if (details == null) {
      _destinationController.addListener(_onDestinationChanged);
      _setStateSafe(() {
        _destinationPredictions = [];
        _isSearchingDestination = false;
      });
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos ubicar ese destino en Popayán. Prueba otra sugerencia.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final destination = TripLocation.fromPlaceDetails(
      placeId: prediction.placeId,
      name: details.name,
      address: details.address,
      lat: details.lat,
      lng: details.lng,
    );

    _destinationController.text = prediction.mainText;
    _destinationController.addListener(_onDestinationChanged);

    _setStateSafe(() {
      _selectedDestination = destination;
      _selectedDestinationArea = null;
      _destinationPredictions = [];
      _isSearchingDestination = false;
      _upsertDestinationMarker(destination);
    });
    unawaited(_ajustarHojaParaSugerencias(false));
    unawaited(_resolveDestBarrio(destination.lat, destination.lng));

    if (mounted) {
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

  /// Sugerencias abiertas: el usuario todavía no eligió el punto.
  bool get _eligiendoEnBusqueda =>
      _isSearchingOrigin ||
      _isSearchingDestination ||
      _originPredictions.isNotEmpty ||
      _destinationPredictions.isNotEmpty;

  /// Hay un campo de búsqueda abierto: todavía no están elegidos los dos puntos.
  bool get _buscandoPunto =>
      _editingPickup ||
      _eligiendoEnBusqueda ||
      _originFocusNode.hasFocus ||
      _destinationFocusNode.hasFocus;

  Future<void> _drawRoute({bool fitCamera = true}) async {
    final origin = _selectedOrigin;
    final destination = _selectedDestination;
    if (origin == null || destination == null || _eligiendoEnBusqueda) return;

    final originLatLng = LatLng(origin.lat, origin.lng);
    final destinationLatLng = LatLng(destination.lat, destination.lng);

    _setStateSafe(() => _isDrawingRoute = true);

    try {
      final routeInfo = await _routesService.getRoute(
        origin: originLatLng,
        destination: destinationLatLng,
      );

      if (!mounted || _eligiendoEnBusqueda) return;
      if (_selectedOrigin != origin || _selectedDestination != destination) {
        return;
      }
      final drawn = routeInfo != null && routeInfo.polylinePoints.length >= 2
          ? routeInfo
          : _straightRoute(originLatLng, destinationLatLng);
      _setStateSafe(() {
        _routeInfo = drawn;
        _polylines = {_routePolyline(drawn.polylinePoints)};
      });

      _syncMarkersOnMap(force: true);
      if (fitCamera) {
        unawaited(_fitCameraToBounds(drawn.polylinePoints));
        FocusScope.of(context).unfocus();
        if (_isExpanded) {
          unawaited(_minimizeSheet());
        }
      }
    } finally {
      if (mounted) {
        _setStateSafe(() => _isDrawingRoute = false);
      }
    }
  }

  Polyline _routePolyline(List<LatLng> points) {
    return Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: Colors.deepOrange,
      width: 5,
      geodesic: true,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
  }

  /// Línea entre los dos puntos. Se pinta al instante y se reemplaza si
  /// el servicio de rutas responde.
  RouteInfo _straightRoute(LatLng origin, LatLng destination) {
    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final km = meters / 1000;
    final minutes = (meters / 500).ceil().clamp(1, 180);
    return RouteInfo(
      polylinePoints: [origin, destination],
      distance: km >= 1 ? '${km.toStringAsFixed(1)} km' : '${meters.round()} m',
      distanceValue: meters.round(),
      duration: '$minutes min',
      durationValue: minutes * 60,
      startAddress: '',
      endAddress: '',
    );
  }

  CameraPosition _overheadCamera(LatLng target, {double? zoom}) {
    return CameraPosition(
      target: target,
      zoom: zoom ?? _mapZoomPasajero,
      tilt: _mapTiltPasajero,
      bearing: _mapBearingPasajero,
    );
  }

  Future<void> _fitCameraToBounds(List<LatLng> points) async {
    final controller = _mapController;
    if (controller == null || points.isEmpty) return;

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

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _beginProgrammaticCamera(center);
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      await Future<void>.delayed(const Duration(milliseconds: 480));
      if (!mounted || _mapController == null) return;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          _overheadCamera(center, zoom: 15.5),
        ),
      );
    } catch (_) {
    } finally {
      _endProgrammaticCamera();
    }
  }

  void _hidePolyline() {
    if (_polylines.isEmpty && _routeInfo == null) return;
    _setStateSafe(() {
      _routeInfo = null;
      _polylines = {};
    });
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
    _syncMarkersOnMap(force: true);

    if (_pickupPin.origen == PinOrigen.gps && _currentPosition != null) {
      _centerToCurrentLocation();
    }
  }

  void _centerToCurrentLocation() {
    final position = _currentPosition;
    if (position == null) return;
    unawaited(_animateCameraTo(position.latitude, position.longitude));
  }

  static const _etiquetasGenericas = {
    'punto seleccionado en el mapa',
    'barrio por confirmar',
    'mi ubicación',
    'mi ubicación actual',
    'escribe tu dirección',
    'ingresa la recogida manualmente',
  };

  /// Nombre que el usuario eligió. Los textos de relleno no sirven en el panel.
  String? _etiquetaElegida(String? value) {
    final texto = value?.trim() ?? '';
    if (texto.isEmpty) return null;
    if (_etiquetasGenericas.contains(texto.toLowerCase())) return null;
    return texto;
  }

  String _primeraEtiqueta(List<String?> candidatas, String respaldo) {
    for (final candidata in candidatas) {
      final elegida = _etiquetaElegida(candidata);
      if (elegida != null) return elegida;
    }
    return respaldo;
  }

  TripLocation _ubicacionParaPedido(
    TripLocation loc, {
    String? textoCampo,
    ServicePin? pin,
  }) {
    final barrioPin = pin?.barrioEfectivo;
    final name = _primeraEtiqueta(
      [loc.name, textoCampo, loc.address, barrioPin?.nombre],
      loc.name,
    );
    final address = _primeraEtiqueta(
      [loc.address, textoCampo, loc.name],
      name,
    );
    return TripLocation(
      placeId: loc.placeId,
      name: name,
      address: address,
      lat: pin?.lat ?? loc.lat,
      lng: pin?.lng ?? loc.lng,
      isCurrentLocation: loc.isCurrentLocation,
      barrio: _etiquetaElegida(loc.barrio) ?? barrioPin?.nombre,
      barrioId: loc.barrioId ??
          (barrioPin != null && barrioPin.id > 0 ? barrioPin.id : null),
      barrioConfirmadoPorUsuario:
          loc.barrioConfirmadoPorUsuario || (pin?.confirmadoPorUsuario ?? false),
      precisionGpsM: loc.precisionGpsM ?? pin?.precisionGpsM,
      origenDelPin: loc.origenDelPin ?? pin?.origenDelPinKey,
    );
  }

  /// El destino del pedido es el lugar elegido. El pin solo aporta el barrio
  /// si sigue en ese mismo punto; si quedó de una selección anterior, no
  /// mueve las coordenadas.
  TripLocation _destinoParaPedido(TripLocation destination) {
    final pin = _destPin;
    final pedido = _ubicacionParaPedido(
      destination,
      textoCampo: _destinationController.text,
      pin: pin,
    );
    if (pin == null) return pedido;
    final drift = PlacePrecision.distanceMeters(
      pin.lat,
      pin.lng,
      destination.lat,
      destination.lng,
    );
    if (drift <= 80) return pedido;
    return TripLocation(
      placeId: pedido.placeId,
      name: pedido.name,
      address: pedido.address,
      lat: destination.lat,
      lng: destination.lng,
      isCurrentLocation: pedido.isCurrentLocation,
      barrio: pedido.barrio,
      barrioId: pedido.barrioId,
      barrioConfirmadoPorUsuario: pedido.barrioConfirmadoPorUsuario,
      precisionGpsM: pedido.precisionGpsM,
      origenDelPin: pedido.origenDelPin,
    );
  }

  TripLocation _tripFromPickupPin({double? lat, double? lng}) {
    final pinLat = lat ?? _pickupPin.lat;
    final pinLng = lng ?? _pickupPin.lng;
    final barrio = _pickupPin.barrioEfectivo;
    return TripLocation(
      name: _pickupPin.barrioNombre,
      address: _pickupPin.barrioNombre,
      lat: pinLat,
      lng: pinLng,
      isCurrentLocation: _pickupPin.origen == PinOrigen.gps,
      barrio: barrio?.nombre,
      barrioId: barrio != null && barrio.id > 0 ? barrio.id : null,
      barrioConfirmadoPorUsuario: _pickupPin.confirmadoPorUsuario,
      precisionGpsM: _pickupPin.precisionGpsM,
      origenDelPin: _pickupPin.origenDelPinKey,
    );
  }

  void _syncOriginFromPickupPin() {
    if (!mounted) return;
    final previous = _selectedOrigin;
    final moved = previous == null
        ? true
        : Geolocator.distanceBetween(
              previous.lat,
              previous.lng,
              _pickupPin.lat,
              _pickupPin.lng,
            ) >
            40;
    final selectedPlace = previous != null &&
        !previous.isCurrentLocation &&
        !moved &&
        _etiquetaElegida(previous.name) != null;
    final barrio = _pickupPin.barrioEfectivo;
    final name = selectedPlace
        ? previous.name
        : (barrio?.nombre ?? 'Punto seleccionado en el mapa');
    final address = selectedPlace ? previous.address : name;

    _selectedOrigin = TripLocation(
      placeId: selectedPlace ? previous.placeId : null,
      name: name,
      address: address,
      lat: _pickupPin.lat,
      lng: _pickupPin.lng,
      isCurrentLocation: _pickupPin.origen == PinOrigen.gps,
      barrio: barrio?.nombre,
      barrioId: barrio != null && barrio.id > 0 ? barrio.id : null,
      barrioConfirmadoPorUsuario: _pickupPin.confirmadoPorUsuario,
      precisionGpsM: _pickupPin.precisionGpsM,
      origenDelPin: _pickupPin.origenDelPinKey,
    );
    _currentLocationName = name;
    _currentLocationArea = barrio?.nombre;
    if (selectedPlace) _currentLocationAddress = address;
  }

  void _schedulePickupBarrioResolve() {
    _barrioDebounce?.cancel();
    _barrioDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_resolvePickupBarrio());
    });
  }

  Future<void> _resolvePickupBarrio() async {
    final result = await _barrioResolver.resolve(_pickupPin.lat, _pickupPin.lng);
    if (!mounted) return;
    _setStateSafe(() {
      _pickupPin.resolve = result;
      if (!_pickupPin.confirmadoPorUsuario) {
        _pickupPin.elegido =
            result.kind == BarrioResolveKind.inside ? result.match : null;
      }
      _syncOriginFromPickupPin();
    });
  }

  void _fijarDestinoPin(double lat, double lng) {
    _destPin ??= ServicePin(
      lat: lat,
      lng: lng,
      origen: PinOrigen.ajusteManual,
    );
    _destPin!
      ..lat = lat
      ..lng = lng
      ..origen = PinOrigen.ajusteManual
      ..resolve = null
      ..elegido = null
      ..confirmadoPorUsuario = false;
  }

  Future<void> _resolveDestBarrio(double lat, double lng) async {
    final generation = ++_destPinGeneration;
    _fijarDestinoPin(lat, lng);
    final result = await _barrioResolver.resolve(lat, lng);
    if (!mounted || generation != _destPinGeneration) return;
    _setStateSafe(() {
      final pin = _destPin;
      if (pin == null) return;
      if (PlacePrecision.distanceMeters(pin.lat, pin.lng, lat, lng) > 40) {
        return;
      }
      pin
        ..resolve = result
        ..elegido = result.kind == BarrioResolveKind.inside ? result.match : null
        ..confirmadoPorUsuario = false;
    });
  }

  void _beginProgrammaticCamera(LatLng target) {
    _programmaticCameraDepth++;
    _programmaticCamera = true;
    _programmaticTarget = target;
    _programmaticIdleUntil =
        DateTime.now().add(const Duration(milliseconds: 1200));
  }

  void _endProgrammaticCamera() {
    if (_programmaticCameraDepth > 0) _programmaticCameraDepth--;
    if (_programmaticCameraDepth == 0) {
      _programmaticCamera = false;
      _programmaticIdleUntil =
          DateTime.now().add(const Duration(milliseconds: 800));
    }
  }

  /// El idle que llega al terminar un movimiento nuestro no es un pin nuevo.
  /// Si el usuario ya arrastró el mapa, la cámara no está en ese punto y sí
  /// se toma como recogida manual.
  bool _idleBelongsToProgrammaticMove(LatLng target) {
    if (_programmaticCamera) return true;
    final programmed = _programmaticTarget;
    if (programmed == null ||
        !DateTime.now().isBefore(_programmaticIdleUntil)) {
      return false;
    }
    return Geolocator.distanceBetween(
          target.latitude,
          target.longitude,
          programmed.latitude,
          programmed.longitude,
        ) <
        25;
  }

  Future<void> _animateCameraTo(double lat, double lng) async {
    final controller = _mapController;
    if (controller == null) return;
    final target = LatLng(lat, lng);
    _beginProgrammaticCamera(target);
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: _mapZoomPasajero,
            tilt: _mapTiltPasajero,
            bearing: _mapBearingPasajero,
          ),
        ),
      );
    } catch (_) {
    } finally {
      _endProgrammaticCamera();
    }
  }

  Future<void> _onPickupCameraIdle() async {
    if (_puntosBloqueados) {
      _setStateSafe(() => _mapMoving = false);
      return;
    }
    final target = _lastCameraTarget;
    if (target != null && _idleBelongsToProgrammaticMove(target)) {
      _setStateSafe(() => _mapMoving = false);
      return;
    }
    if (target == null) {
      _setStateSafe(() => _mapMoving = false);
      return;
    }
    if (!mounted) return;
    _namedPickupLocked = false;
    _pickupPin
      ..lat = target.latitude
      ..lng = target.longitude
      ..origen = PinOrigen.ajusteManual
      ..resolve = null
      ..elegido = null
      ..confirmadoPorUsuario = false;
    _setStateSafe(() {
      _mapMoving = false;
      _originEditedByUser = true;
      _syncOriginFromPickupPin();
    });
    _syncMarkersOnMap(force: true);
    _schedulePickupBarrioResolve();
  }

  Future<void> _cambiarBarrioPickup() async {
    final chosen = await showBarrioSearchSheet(
      context: context,
      resolver: _barrioResolver,
      currentName: _pickupPin.barrioEfectivo?.nombre,
    );
    if (!mounted) return;
    _setStateSafe(() {
      if (chosen != null) {
        _pickupPin.elegido = chosen;
        _pickupPin.confirmadoPorUsuario = true;
      } else {
        _pickupPin.elegido = null;
        _pickupPin.confirmadoPorUsuario = true;
      }
      _syncOriginFromPickupPin();
    });
  }

  void _elegirBarrioPickup(Barrio barrio) {
    _setStateSafe(() {
      _pickupPin.elegido = barrio;
      _pickupPin.confirmadoPorUsuario = true;
      _syncOriginFromPickupPin();
    });
  }

  Future<void> _cambiarBarrioDestino() async {
    final pin = _destPin;
    if (pin == null) return;
    final chosen = await showBarrioSearchSheet(
      context: context,
      resolver: _barrioResolver,
      currentName: pin.barrioEfectivo?.nombre,
    );
    if (!mounted) return;
    _setStateSafe(() {
      if (chosen != null) {
        pin.elegido = chosen;
        pin.confirmadoPorUsuario = true;
      } else {
        pin.elegido = null;
        pin.confirmadoPorUsuario = true;
      }
    });
  }

  void _elegirBarrioDestino(Barrio barrio) {
    _setStateSafe(() {
      _destPin?.elegido = barrio;
      _destPin?.confirmadoPorUsuario = true;
    });
  }

  void _requestRide() {
    if (_isSubmittingRide) return;
    unawaited(_confirmAndRequestRide());
  }

  Future<void> _confirmAndRequestRide() async {
    if (!_canRequestRide) {
      final reason = !_pickupPin.gpsListo
          ? 'Espera a que el GPS baje de 30 m o mueve el pin a mano.'
          : _pickupPin.necesitaElegirBarrio &&
                  !_pickupPin.barrioPorConfirmar
                  ? 'Elige el barrio de recogida para continuar.'
                  : 'Completa destino y barrio para continuar.';
      _scaffoldMessenger?.showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    await _handleRideConfirmation();
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

  /// Recogida = el lugar que eligió el pasajero, con el barrio aparte.
  Future<TripLocation> _originForRequest(TripLocation origin) async {
    final requestOrigin = _ubicacionParaPedido(
      origin,
      textoCampo: _originController.text,
      pin: _pickupPin,
    );
    _setStateSafe(() {
      _selectedOrigin = requestOrigin;
      _currentLocationArea = requestOrigin.barrio;
      _currentLocationName = requestOrigin.name;
    });
    return requestOrigin;
  }

  Future<void> _handleRideConfirmation() async {
    if (_isSubmittingRide) return;

    final isDelivery = _serviceType == 'domicilio';
    final origin = _selectedOrigin;
    var destination = _selectedDestination;
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

    final bool isDirectFlow = _nearbyDrivers.selectedDirectDriver != null;
    final Conductor? selectedConductor = _nearbyDrivers.selectedDirectDriver;

    _setStateSafe(() => _isSubmittingRide = true);

    try {
      final preciseOrigin = await _originForRequest(origin);
      if (destination != null) {
        destination = _destinoParaPedido(destination);
      }

      final response = isDirectFlow
          ? await _rideRequestService.sendDirectOffer(
              conductorId: selectedConductor!.conductorId,
              pasajeroId: pasajeroId,
              origin: preciseOrigin,
              destination: destination,
              distancia: route?.distance,
              duracionEstimada: route?.duration,
              precioOfrecido: 0,
            )
          : await _rideRequestService.requestRide(
              origin: preciseOrigin,
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
              'origen_lat': preciseOrigin.lat,
              'origen_lng': preciseOrigin.lng,
              'origen_address': preciseOrigin.address,
              'origen_name': preciseOrigin.name,
              if (preciseOrigin.barrio != null)
                'origen_barrio': preciseOrigin.barrio,
              if (preciseOrigin.barrioId != null)
                'origen_barrio_id': preciseOrigin.barrioId,
              'origen_barrio_confirmado_por_usuario':
                  preciseOrigin.barrioConfirmadoPorUsuario,
              if (preciseOrigin.precisionGpsM != null)
                'origen_precision_gps_m': preciseOrigin.precisionGpsM,
              if (preciseOrigin.origenDelPin != null)
                'origen_pin_origen': preciseOrigin.origenDelPin,
              'destino_lat': destination?.lat,
              'destino_lng': destination?.lng,
              'destino_address': destination?.address ?? 'Destino no definido',
              if (destination?.barrio != null)
                'destino_barrio': destination!.barrio,
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
            force: true,
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
    int? fromMap(Map map) {
      for (final key in const ['solicitud_id', 'servicio_id', 'id']) {
        final value = map[key];
        if (value == null) continue;
        if (value is int && value > 0) return value;
        final parsed = int.tryParse(value.toString());
        if (parsed != null && parsed > 0) return parsed;
      }
      if (map['servicio'] is Map) {
        return fromMap(map['servicio'] as Map);
      }
      return null;
    }

    return fromMap(response) ??
        (response['data'] is Map ? fromMap(response['data'] as Map) : null);
  }

  Future<void> _onDriverMarkerTap(Conductor conductor) async {
    final alreadySelected =
        _nearbyDrivers.selectedDirectDriver?.conductorId == conductor.conductorId;

    _setStateSafe(() {
      _nearbyDrivers.selectedDirectDriver = alreadySelected ? null : conductor;
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

    await _confirmAndRequestRide();
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

  // ========== MÉTODOS DE SOCKET - CONTRAOFERTAS ==========

  /// Configura la conexión a Pusher para recibir la confirmación de solicitud creada
  Future<void> _setupSocketRequestConfirmation() async {
    try {
      AppLogger.d('🚀 Configurando socket para confirmación de solicitudes...');
      await _socketOffers.subscribeRequestConfirmation(
        onNuevaSolicitud: _manejarNuevaSolicitud,
      );
      AppLogger.d(
        '✅ Socket configurado - Esperando confirmación en canal solicitudes-servicio',
      );
    } catch (e) {
      AppLogger.d('❌ Error configurando socket: $e');
    }
  }

  /// Maneja la llegada de la confirmación de solicitud creada
  void _manejarNuevaSolicitud(Map<String, dynamic> solicitudData) {
    AppLogger.d('🚕 _manejarNuevaSolicitud llamado en PASAJERO');
    AppLogger.d('📦 Datos recibidos: $solicitudData');

    if (!mounted) {
      AppLogger.d('⚠️ Widget no montado, ignorando solicitud');
      return;
    }

    try {
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
  Future<void> _setupSocketOffers() async {
    if (!_enableGlobalOffersChannel) {
      AppLogger.d('⏭️ Canal ofertas-globales deshabilitado');
      return;
    }

    try {
      AppLogger.d('🚀 Configurando socket para ofertas globales...');
      await _socketOffers.subscribeGlobalOffers(onNewOffer: _handleNewOffer);
      AppLogger.d(
        '✅ Socket configurado - Esperando ofertas en canal ofertas-globales',
      );
    } catch (e) {
      AppLogger.d('❌ Error configurando socket: $e');
    }
  }

  /// Maneja la llegada de una nueva contraoferta
  void _handleNewOffer(Map<String, dynamic> offerData) {
    AppLogger.d('🎉 ¡Nueva contraoferta recibida!');

    try {
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

  int? _parseOfferId(Map<String, dynamic> offer) {
    final raw = offer['oferta_id'] ?? offer['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  /// Acepta la contraoferta del conductor
  Future<void> _acceptOffer() async {
    if (_currentOffer == null || _isProcessingOffer) return;

    final ofertaId = _parseOfferId(_currentOffer!);
    if (ofertaId == null) {
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Oferta inválida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final conductorNombre =
        _currentOffer!['conductor_nombre']?.toString() ?? 'Conductor';

    _setStateSafe(() => _isProcessingOffer = true);
    try {
      AppLogger.d('✅ Aceptando oferta: $ofertaId');
      final response = await _rideRequestService.acceptCounterOffer(
        ofertaId: ofertaId,
      );

      if (!mounted) return;

      final servicioId = _parseServicioIdFromResponse(response) ??
          int.tryParse(_currentOffer!['servicio_id']?.toString() ?? '') ??
          int.tryParse(_currentOffer!['solicitud_id']?.toString() ?? '');

      _setStateSafe(() {
        _showOffer = false;
        _currentOffer = null;
      });

      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text('✅ ¡Oferta aceptada! $conductorNombre va en camino'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      if (servicioId != null && mounted) {
        final restoration = ActiveServiceRestorationService();
        final detalle = await restoration.verificarServicioActivoPasajero();
        if (!mounted) return;

        if (detalle != null &&
            ServiceNavigationHelper.shouldShowActiveService(detalle)) {
          await ServiceNavigationHelper.navigateToActiveService(
            context,
            detalle,
            Provider.of<AuthProvider>(context, listen: false),
            force: true,
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
      }
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', '').trim(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) _setStateSafe(() => _isProcessingOffer = false);
    }
  }

  /// Rechaza la contraoferta del conductor
  Future<void> _rejectOffer() async {
    if (_currentOffer == null || _isProcessingOffer) return;

    final ofertaId = _parseOfferId(_currentOffer!);
    if (ofertaId == null) {
      _dismissOffer();
      return;
    }

    _setStateSafe(() => _isProcessingOffer = true);
    try {
      AppLogger.d('❌ Rechazando oferta: $ofertaId');
      await _rideRequestService.rejectCounterOffer(ofertaId: ofertaId);

      if (!mounted) return;

      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Oferta rechazada. Esperando más conductores...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      _setStateSafe(() {
        _showOffer = false;
        _currentOffer = null;
      });
    } catch (e) {
      if (!mounted) return;
      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', '').trim(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) _setStateSafe(() => _isProcessingOffer = false);
    }
  }

  /// Cierra la oferta sin aceptar ni rechazar
  void _dismissOffer() {
    _setStateSafe(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }
}
