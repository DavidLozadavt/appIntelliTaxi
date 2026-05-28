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
import 'package:intellitaxi/features/rides/presentation/active_service_screen.dart';
import 'package:intellitaxi/features/pasajero/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/conductor/data/conductor_model.dart';
// import 'package:intellitaxi/features/pasajero/travel_assistant/travel_assistant_screen.dart';
import 'package:intellitaxi/features/pasajero/widgets/no_drivers_available_dialog.dart';
import 'package:intellitaxi/features/pasajero/widgets/ride_request_floating_cta.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/services/service_navigation_helper.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_active_service_controller.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_nearby_drivers_controller.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_places_search_controller.dart';
import 'package:intellitaxi/features/pasajero/controllers/pasajero_pusher_offers_controller.dart';
import 'package:intellitaxi/core/services/device_location_service.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/pasajero/widgets/pasajero_home_ride_sheet.dart';

class HomePasajero extends StatefulWidget {
  final List<dynamic> stories;

  const HomePasajero({super.key, required this.stories});

  @override
  State<HomePasajero> createState() => _HomePasajeroState();
}

enum _SheetVisualState { compact, middle, expanded }

class _HomePasajeroState extends State<HomePasajero>
    with TickerProviderStateMixin {
  /// Vista cenital tipo apps de movilidad (sin inclinación 3D).
  static const double _mapZoomPasajero = 16.5;
  static const double _mapTiltPasajero = 0;
  static const double _mapBearingPasajero = 0;

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
  bool _isResolvingMapDestination = false;
  late final PasajeroPlacesSearchController _placesSearch;
  final PasajeroPusherOffersController _pusherOffers =
      PasajeroPusherOffersController();
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
  bool _isDisposed = false;
  String _currentLocationName = 'Mi ubicación';
  String _currentLocationAddress = 'Mi ubicación actual';
  String? _currentLocationArea;
  String? _currentLocationStreet;
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
    _placesSearch = PasajeroPlacesSearchController(placesService: _placesService);
    _createUserMarkerIcon();
    unawaited(_nearbyDrivers.loadDriverMarkerIcon().then((_) {
      if (mounted) _setStateSafe(() {});
    }));
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
    if (!mounted || _isDisposed) return;
    if (_nearbyDrivers.tickMarkerAnimation(showDrivers: _showDrivers)) {
      _syncMarkersOnMap();
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

    _activeServiceController.dispose();

    // Limpiar referencia al ScaffoldMessenger
    _scaffoldMessenger = null;

    _pusherOffers.unsubscribeAll(
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
    _originController.dispose();
    _destinationController.dispose();
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

  Future<void> _checkActiveService() async {
    final servicio = await _activeServiceController.fetchActiveServiceIfAny();
    if (servicio == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveServiceScreen(
          servicio: servicio,
          onServiceCompleted: () async {
            if (!mounted) return;
            Navigator.of(context).pop();
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) await _loadAvailableDrivers();
          },
        ),
      ),
    );

    _startServiceTracking(servicio.id);
  }

  void _startServiceTracking(int servicioId) {
    _activeServiceController.startTracking(
      servicioId: servicioId,
      onUpdated: (servicio) {
        if (!mounted) return;
        AppLogger.d('🔄 Servicio actualizado: ${servicio.estado.estado}');
      },
      onCompleted: () {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) await _loadAvailableDrivers();
        });
      },
    );
  }

  // ========== MÉTODOS DE CONDUCTORES DISPONIBLES ==========

  Future<void> _setupPusherConductores() async {
    await _nearbyDrivers.connectPusher(
      onDriverUpdate: (conductor) {
        if (!mounted) return;
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
        _nearbyDrivers.removeDriver(conductorId);
        _syncMarkersOnMap();
      },
    );
  }

  Future<void> _loadAvailableDrivers({bool silent = false}) async {
    if (_currentPosition == null) return;
    await _nearbyDrivers.loadFromApi(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      silent: silent,
    );
    if (mounted) _syncMarkersOnMap();
  }

  /// Recompone marcadores del mapa (conductores animados + ruta + resto).
  InfoWindow _userLocationInfoWindow() {
    final title = _currentLocationArea ?? _currentLocationName;
    final snippet = _currentLocationStreet ??
        (_currentLocationAddress != title ? _currentLocationAddress : '');
    return InfoWindow(title: title, snippet: snippet);
  }

  String get _originPickupLabel {
    final barrio = _currentLocationArea?.trim();
    if (barrio != null && barrio.isNotEmpty) return 'Barrio: $barrio';
    return _currentLocationStreet ?? _currentLocationName;
  }

  String get _pickupDisplayLabel {
    if (_selectedOrigin != null &&
        _currentPosition != null &&
        _selectedOrigin!.lat == _currentPosition!.latitude &&
        _selectedOrigin!.lng == _currentPosition!.longitude) {
      return _originPickupLabel;
    }
    return _selectedOrigin?.name ?? _originPickupLabel;
  }

  void _syncMarkersOnMap() {
    if (!mounted || _isDisposed) return;

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
                  actionLabel: 'Reintentar ubicación',
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
                  onTap: _onMapTap,
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
                return PasajeroHomeRideSheet(
                  scrollController: scrollController,
                  sheetExtent: _sheetExtent,
                  serviceType: _serviceType,
                  selectedOrigin: _selectedOrigin,
                  selectedDestination: _selectedDestination,
                  selectedDestinationArea: _selectedDestinationArea,
                  routeInfo: _routeInfo,
                  pickupDisplayLabel: _pickupDisplayLabel,
                  pickupStreetDetail: _currentLocationStreet,
                  originController: _originController,
                  destinationController: _destinationController,
                  destinationFocusNode: _destinationFocusNode,
                  originPredictions: _originPredictions,
                  destinationPredictions: _destinationPredictions,
                  isSearchingOrigin: _isSearchingOrigin,
                  isSearchingDestination: _isSearchingDestination,
                  recentDestinations: _recentDestinations,
                  destinationSummaryText: _destinationSummaryText,
                  onToggleSheet: _toggleSheet,
                  onOpenQuickRequest: _openQuickRequestFlow,
                  onServiceTypeChanged: (type) {
                    _setStateSafe(() {
                      _serviceType = type;
                      _clearRoute();
                    });
                  },
                  onSelectOrigin: _selectOrigin,
                  onSelectDestination: _selectDestination,
                  onClearOrigin: () {
                    _setStateSafe(() {
                      _originController.clear();
                      _selectedOrigin = null;
                      _originPredictions = [];
                    });
                  },
                  onClearDestination: () {
                    _setStateSafe(() {
                      _destinationController.clear();
                      _selectedDestination = null;
                      _selectedDestinationArea = null;
                      _destinationPredictions = [];
                      _clearRoute();
                    });
                  },
                  onRecentDestinationTap: _applyDestinationLocation,
                  onSaveFavoriteDestination: _saveFavoriteDestination,
                );
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

    if (!await DeviceLocationService.isServiceEnabled()) {
      final permission =
          await DeviceLocationService.locationPermissionStatus();
      _setStateSafe(() {
        _isLoadingLocation = false;
        _locationMessage = DeviceLocationService.messageForFailure(
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
        _isLoadingLocation = false;
        _locationMessage = DeviceLocationService.messageForFailure(
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
          _isLoadingLocation = false;
          _locationMessage = DeviceLocationService.messageForFailure(
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

      _applyOriginFromGps(position, markReady: true);
      unawaited(_refineOriginAddress(position));

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            _overheadCamera(
              LatLng(position.latitude, position.longitude),
            ),
          ),
        );
      }

      unawaited(_loadAvailableDrivers());
      _startDriversRefreshTimer();
      unawaited(_requestNotificationPermissionAfterLocation());
      _tryApplyPendingRepeatTrip();
    } catch (e) {
      AppLogger.e('Error GPS pasajero', tag: 'HomePasajero', error: e);
      if (mounted) {
        final permission =
            await DeviceLocationService.locationPermissionStatus();
        _setStateSafe(() {
          _isLoadingLocation = false;
          _locationMessage = DeviceLocationService.messageForFailure(
            serviceEnabled: true,
            permission: permission,
          );
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
            infoWindow: _userLocationInfoWindow(),
          ),
        };
      }
    });
  }

  Future<void> _refineOriginAddress(Position position) async {
    final nearby = await _placesService.findNearestPlaceAt(
      position.latitude,
      position.longitude,
      maxDistanceMeters: 100,
    );

    final locationData = await _getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (!mounted) return;

    final poiName = nearby?.name.trim();
    final usePoiName = poiName != null &&
        poiName.isNotEmpty &&
        !SolicitudDisplayHelper.looksLikeStreetAddress(poiName);

    _setStateSafe(() {
      _currentLocationName = usePoiName ? poiName : locationData.pickupLabel;
      _currentLocationArea = locationData.area;
      _currentLocationStreet = locationData.streetLine;
      _currentLocationAddress = nearby?.address.trim().isNotEmpty == true
          ? nearby!.address
          : locationData.address;

      if (_selectedOrigin != null) {
        _selectedOrigin = TripLocation(
          placeId: nearby?.placeId,
          name: _currentLocationName,
          address: _currentLocationAddress,
          lat: position.latitude,
          lng: position.longitude,
          isCurrentLocation: true,
        );
        _originController.removeListener(_onOriginChanged);
        _originController.text = _originPickupLabel;
        _originController.addListener(_onOriginChanged);
      }

      _syncMarkersOnMap();
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

  Future<void> _onMapTap(LatLng latLng) async {
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
      },
    );
  }

  void _onDestinationChanged() {
    if (!mounted) return;
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
      },
    );
  }

  Future<void> _selectOrigin(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _originController.removeListener(_onOriginChanged);

    final details = await _placesSearch.resolvePlace(prediction);

    if (!mounted) return;
    _originController.addListener(_onOriginChanged);

    if (details == null) {
      _setStateSafe(() {
        _originPredictions = [];
        _isSearchingOrigin = false;
      });
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'La recogida debe estar dentro del perímetro urbano de Popayán.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    if (_selectedDestination != null) {
      await _drawRoute();
    }
  }

  Future<void> _selectDestination(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _destinationController.removeListener(_onDestinationChanged);

    final details = await _placesSearch.resolvePlace(prediction);

    if (!mounted) return;
    _destinationController.addListener(_onDestinationChanged);

    if (details == null) {
      _setStateSafe(() {
        _destinationPredictions = [];
        _isSearchingDestination = false;
      });
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'El destino debe estar dentro del perímetro urbano de Popayán.',
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

    _setStateSafe(() {
      _selectedDestination = destination;
      _selectedDestinationArea = null;
      _destinationController.text = prediction.mainText;
      _destinationPredictions = [];
      _isSearchingDestination = false;
      _upsertDestinationMarker(destination);
    });

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

  CameraPosition _overheadCamera(LatLng target, {double? zoom}) {
    return CameraPosition(
      target: target,
      zoom: zoom ?? _mapZoomPasajero,
      tilt: _mapTiltPasajero,
      bearing: _mapBearingPasajero,
    );
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
    // Tras encuadrar la ruta, volver a vista plana (sin tilt 3D).
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _mapController == null) return;
      final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          _overheadCamera(center, zoom: 15.5),
        ),
      );
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

    if (_currentPosition != null) {
      _centerToCurrentLocation();
    }
  }

  void _centerToCurrentLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          _overheadCamera(
            LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
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

    final bool isDirectFlow = _nearbyDrivers.selectedDirectDriver != null;
    final Conductor? selectedConductor = _nearbyDrivers.selectedDirectDriver;

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
      await _pusherOffers.subscribeRequestConfirmation(
        onNuevaSolicitud: _manejarNuevaSolicitud,
      );
      AppLogger.d(
        '✅ Pusher configurado - Esperando confirmación en canal solicitudes-servicio',
      );
    } catch (e) {
      AppLogger.d('❌ Error configurando Pusher: $e');
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
  Future<void> _setupPusherOffers() async {
    if (!_enableGlobalOffersChannel) {
      AppLogger.d('⏭️ Canal ofertas-globales deshabilitado');
      return;
    }

    try {
      AppLogger.d('🚀 Configurando Pusher para ofertas globales...');
      await _pusherOffers.subscribeGlobalOffers(onNewOffer: _handleNewOffer);
      AppLogger.d(
        '✅ Pusher configurado - Esperando ofertas en canal ofertas-globales',
      );
    } catch (e) {
      AppLogger.d('❌ Error configurando Pusher: $e');
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
