import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';
import 'package:intellitaxi/features/pasajero/services/ride_request_service.dart';
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
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/service_type_selector.dart';
import 'package:intellitaxi/features/pasajero/widgets/route_info_card.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/pasajero/widgets/waiting_for_driver_dialog.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';

class HomePasajero extends StatefulWidget {
  final List<dynamic> stories;

  const HomePasajero({super.key, required this.stories});

  @override
  State<HomePasajero> createState() => _HomePasajeroState();
}

class _CurrentLocationData {
  final String name;
  final String address;

  const _CurrentLocationData({required this.name, required this.address});
}

enum _SheetVisualState { compact, middle, expanded }

class _HomePasajeroState extends State<HomePasajero> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Verificando tu ubicación actual con GPS de alta precisión...';

  // Para el bottom sheet con snap
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  static const double _sheetMinSize = 0.18;
  static const double _sheetMidSize = 0.50;
  static const double _sheetMaxSize = 0.88;
  double _sheetSize = _sheetMinSize;
  _SheetVisualState _sheetVisualState = _SheetVisualState.compact;
  _SheetVisualState? _lastHapticSnap;
  DateTime _lastSheetFrameUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Para las búsquedas
  final PlacesService _placesService = PlacesService();
  final RoutesService _routesService = RoutesService();
  final RideRequestService _rideRequestService = RideRequestService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();

  TripLocation? _selectedOrigin;
  TripLocation? _selectedDestination;
  RouteInfo? _routeInfo;

  List<PlacePrediction> _originPredictions = [];
  List<PlacePrediction> _destinationPredictions = [];
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;
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
  Conductor? _selectedDirectDriver;
  BitmapDescriptor? _driverMarkerIcon;
  final bool _showDrivers = true; // Toggle para mostrar/ocultar conductores
  bool _isDisposed = false;
  String _currentLocationName = 'Mi ubicación';
  String _currentLocationAddress = 'Mi ubicación actual';
  bool _prefsLoaded = false;
  List<TripLocation> _recentDestinations = [];

  bool get _isExpanded => _sheetVisualState != _SheetVisualState.compact;

  double get _sheetProgress {
    final raw = (_sheetSize - _sheetMinSize) / (_sheetMaxSize - _sheetMinSize);
    return raw.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _createUserMarkerIcon();
    _createDriverMarkerIcon();
    _initializeLocation();
    _setupPusherOffers();
    _setupPusherRequestConfirmation();
    _checkActiveService(); // Verificar servicio activo al iniciar
    _setupPusherConductores(); // Configurar Pusher para conductores

    // Listeners
    _originController.addListener(_onOriginChanged);
    _destinationController.addListener(_onDestinationChanged);
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
    PusherService.unregisterEventHandlerSecondary(
      'solicitudes-servicio:nueva-solicitud',
    );

    // Remover listeners de los controladores de texto ANTES de disponer
    _originController.removeListener(_onOriginChanged);
    _destinationController.removeListener(_onDestinationChanged);

    // Desconectar servicio de conductores
    _pusherConductoresService?.disconnect();

    _mapController?.dispose();
    _sheetController.dispose();
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
  Future<void> _loadAvailableDrivers() async {
    if (_currentPosition == null) {
      AppLogger.d('⚠️ No hay posición actual para buscar conductores');
      return;
    }

    try {
      AppLogger.d('🔍 Cargando conductores disponibles...');
      AppLogger.d(
        '   📊 Conductores actuales en memoria: ${_conductoresDisponibles.length}',
      );

      final conductores = await _conductoresService.getConductoresDisponibles(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        radioKm: 15, // Aumentar radio para mejor cobertura
      );

      if (!mounted) return;

      _setStateSafe(() {
        // NO limpiar todos los conductores, solo actualizar los que vienen de la API
        // Esto preserva conductores que llegaron por Pusher pero no están en la consulta

        // Primero, actualizar o agregar conductores de la API
        for (var conductor in conductores) {
          _conductoresDisponibles[conductor.conductorId] = conductor;
        }

        // Opcional: Limpiar conductores que hace mucho no se actualizan
        // (esto se puede agregar después si es necesario)
      });

      // Actualizar marcadores
      _updateAllDriverMarkers();

      AppLogger.d('✅ ${conductores.length} conductores desde API');
      AppLogger.d(
        '   📍 Total en mapa: ${_conductoresDisponibles.length} conductores',
      );
    } catch (e) {
      AppLogger.d('❌ Error cargando conductores: $e');
    }
  }

  /// Actualiza el marcador de un conductor específico
  void _updateDriverMarker(Conductor conductor) {
    if (!_showDrivers) return;

    _setStateSafe(() {
      _conductoresDisponibles[conductor.conductorId] = conductor;
      _updateAllDriverMarkers();
    });

    AppLogger.d('📍 Marcador actualizado: ${conductor.nombre}');
  }

  /// Elimina el marcador de un conductor
  void _removeDriverMarker(int conductorId) {
    _setStateSafe(() {
      if (_selectedDirectDriver?.conductorId == conductorId) {
        _selectedDirectDriver = null;
      }
      _conductoresDisponibles.remove(conductorId);
      _updateAllDriverMarkers();
    });

    AppLogger.d('🔴 Conductor removido: $conductorId');
  }

  /// Actualiza todos los marcadores en el mapa
  void _updateAllDriverMarkers() {
    AppLogger.d('🔄 _updateAllDriverMarkers llamado');
    AppLogger.d('   🚗 _showDrivers: $_showDrivers');
    AppLogger.d(
      '   📊 Conductores en memoria: ${_conductoresDisponibles.length}',
    );

    final Set<Marker> newMarkers = {};

    // Agregar marcadores de conductores solo si están visibles
    if (_showDrivers) {
      AppLogger.d('   ✅ Agregando marcadores de conductores...');
      for (var conductor in _conductoresDisponibles.values) {
        AppLogger.d(
          '      🚗 Agregando: ${conductor.nombre} en (${conductor.lat}, ${conductor.lng})',
        );
        newMarkers.add(
          Marker(
            markerId: MarkerId('driver_${conductor.conductorId}'),
            position: LatLng(conductor.lat, conductor.lng),
            icon:
                _driverMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
            infoWindow: InfoWindow(
              title: '🚗 ${conductor.nombre}',
              snippet:
                  '⭐ ${conductor.calificacion.toStringAsFixed(1)} • '
                  '${conductor.vehiculo?.descripcion ?? "Sin vehículo"}\n'
                  '📏 ${conductor.distanciaKm != null ? "${conductor.distanciaKm!.toStringAsFixed(2)} km" : ""}',
            ),
            onTap: () => _onDriverMarkerTap(conductor),
            zIndexInt: 1, // Debajo de otros marcadores
          ),
        );
      }
      AppLogger.d(
        '   ✅ ${newMarkers.length} marcadores de conductores agregados',
      );
    } else {
      AppLogger.d('   ⚠️ _showDrivers es false, NO se agregan conductores');
    }

    // Agregar marcadores existentes que NO sean de conductores (ruta, origen, destino, etc)
    for (var marker in _markers) {
      if (!marker.markerId.value.startsWith('driver_')) {
        newMarkers.add(marker);
      }
    }

    // Si hay ubicación actual y no hay ruta, mostrar marcador de usuario
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
          zIndexInt: 10, // Encima de todos
        ),
      );
    }

    _setStateSafe(() {
      _markers = newMarkers;
    });

    AppLogger.d(
      '🗺️ Marcadores actualizados: ${_conductoresDisponibles.length} conductores, ${newMarkers.length} marcadores totales',
    );

    // Debug: Listar todos los marcadores
    AppLogger.d('   📍 Marcadores en el mapa:');
    for (var marker in newMarkers) {
      AppLogger.d('      - ${marker.markerId.value}');
    }
  }

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
            : StandardMap(
                initialPosition: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 15,
                polylines: _polylines,
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),

        // Overlay ligero: mejora legibilidad sin costo alto de blur en tiempo real
        if (_currentPosition != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: (_sheetProgress * 0.18).clamp(0.0, 0.18),
                child: Container(color: Colors.black),
              ),
            ),
          ),

        // Bottom Sheet Persistente (snap)
        if (_currentPosition != null)
          Positioned.fill(
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                if (!mounted) return false;
                final nextSize = notification.extent;
                if (_shouldApplySheetFrameUpdate(nextSize)) {
                  _setStateSafe(() => _sheetSize = nextSize);
                }
                final nextVisualState = _sheetStateFromExtent(nextSize);
                if (nextVisualState != _sheetVisualState) {
                  _setStateSafe(() => _sheetVisualState = nextVisualState);
                }
                _emitSnapHapticIfNeeded(nextSize, nextVisualState);
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: _sheetMinSize,
                minChildSize: _sheetMinSize,
                maxChildSize: _sheetMaxSize,
                expand: false,
                snap: true,
                snapAnimationDuration: const Duration(milliseconds: 220),
                snapSizes: const [_sheetMinSize, _sheetMidSize, _sheetMaxSize],
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _toggleSheet,
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isExpanded
                              ? _buildExpandedContent(
                                  scrollController: scrollController,
                                  showInlineActions: false,
                                )
                              : ListView(
                                  controller: scrollController,
                                  physics: const ClampingScrollPhysics(),
                                  children: [_buildMinimizedContent()],
                                ),
                        ),
                        _buildFixedCta(),
                      ],
                    ),
                  );
                },
              ),
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

  Widget _buildMinimizedContent() {
    final compact = _sheetVisualState == _SheetVisualState.compact;
    final title = _serviceType == 'taxi' ? '¿A dónde vas?' : 'Enviar domicilio';
    final subtitle = _routeInfo != null
        ? '${_routeInfo!.distance} • Cobro por taxímetro'
        : (_selectedOrigin != null
              ? 'Desde ${_selectedOrigin!.name}'
              : 'Toca para seleccionar destino');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openQuickRequestFlow,
        child: Column(
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: compact ? 50 : 46,
                  height: compact ? 50 : 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _serviceType == 'taxi'
                          ? [Colors.deepOrange, Colors.orangeAccent]
                          : [Colors.green.shade600, Colors.green.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _serviceType == 'taxi'
                        ? Icons.local_taxi
                        : Icons.shopping_bag,
                    color: Colors.white,
                    size: compact ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) {
                          final offset = Tween<Offset>(
                            begin: const Offset(0, 0.18),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          title,
                          key: ValueKey<String>('title_$title'),
                          style: TextStyle(
                            fontSize: compact ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: Text(
                          subtitle,
                          key: ValueKey<String>('subtitle_$subtitle'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: _isExpanded ? 0.5 : 0.0,
                  child: const Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent({
    ScrollController? scrollController,
    bool showInlineActions = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        Text(
          _serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Selector de tipo de servicio (primero)
        ServiceTypeSelector(
          selectedType: _serviceType,
          onTypeChanged: (type) {
            _setStateSafe(() {
              _serviceType = type;
              _clearRoute();
            });
          },
        ),

        const SizedBox(height: 14),

        // Campo de origen
        LocationSearchField(
          controller: _originController,
          label: 'Origen',
          icon: Icons.my_location,
          iconColor: Colors.green,
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

        const SizedBox(height: 12),

        // Campo de destino
        LocationSearchField(
          controller: _destinationController,
          label: 'Destino',
          icon: Icons.location_on,
          iconColor: Colors.red,
          focusNode: _destinationFocusNode,
          predictions: _destinationPredictions,
          isSearching: _isSearchingDestination,
          onSelectPrediction: _selectDestination,
          onClear: () {
            _setStateSafe(() {
              _destinationController.clear();
              _selectedDestination = null;
              _destinationPredictions = [];
              _clearRoute();
            });
          },
        ),

        if (_selectedDestination != null) ...[
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

        const SizedBox(height: 14),

        if (_recentDestinations.isNotEmpty) ...[_buildRecentDestinationChips()],

        const SizedBox(height: 24),

        if (showInlineActions &&
            _selectedOrigin != null &&
            _selectedDestination != null &&
            _routeInfo == null)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _drawRoute,
              icon: const Icon(Icons.route),
              label: const Text(
                'Ver ruta en el mapa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

        if (_routeInfo != null) ...[
          RouteInfoCard(routeInfo: _routeInfo!),
          if (showInlineActions) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _requestRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _serviceType == 'taxi'
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _serviceType == 'taxi'
                      ? 'Solicitar viaje'
                      : 'Solicitar domicilio',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),

        // Info de búsqueda
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withValues(alpha: isDark ? 0.5 : 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Búsqueda limitada a Popayán y alrededores',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFixedCta() {
    // En estado compacto no hay espacio vertical suficiente para un CTA fijo.
    if (_sheetVisualState == _SheetVisualState.compact) {
      return const SizedBox.shrink();
    }

    String label;
    VoidCallback? onPressed;
    Color color;

    if (_selectedOrigin != null &&
        _selectedDestination != null &&
        _routeInfo == null) {
      label = 'Ver ruta en el mapa';
      onPressed = _drawRoute;
      color = Colors.deepOrange;
    } else if (_routeInfo != null) {
      label = _serviceType == 'taxi'
          ? 'Solicitar viaje'
          : 'Solicitar domicilio';
      onPressed = _requestRide;
      color = _serviceType == 'taxi'
          ? Colors.green.shade600
          : Colors.orange.shade600;
    } else {
      label = 'Selecciona origen y destino';
      onPressed = null;
      color = Colors.grey;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: Row(
                key: ValueKey<String>('cta_$label'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _routeInfo != null
                        ? Icons.check_circle_outline
                        : Icons.keyboard_arrow_up,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      const double markerSize = 64.0;
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
  Future<_CurrentLocationData> _getAddressFromCoordinates(
    double lat,
    double lng,
  ) async {
    final fallbackAddress =
        'Lat ${lat.toStringAsFixed(5)}, Lng ${lng.toStringAsFixed(5)}';
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=$lat,$lng'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final results = data['results'] as List<dynamic>;
          final first = results.first as Map<String, dynamic>;
          final formattedAddress =
              first['formatted_address']?.toString().trim() ?? '';

          String? bestName;
          for (final item in results) {
            if (item is! Map<String, dynamic>) continue;
            final value = item['formatted_address']?.toString().trim();
            if (value == null || value.isEmpty) continue;

            final firstSegment = value.split(',').first.trim();
            if (firstSegment.isNotEmpty && firstSegment.length >= 3) {
              bestName = firstSegment;
              break;
            }
          }

          return _CurrentLocationData(
            name: (bestName == null || bestName.isEmpty)
                ? 'Mi ubicación'
                : bestName,
            address: formattedAddress.isEmpty
                ? fallbackAddress
                : formattedAddress,
          );
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo dirección: $e');
    }
    return _CurrentLocationData(name: 'Mi ubicación', address: fallbackAddress);
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
      _setStateSafe(
        () => _locationMessage =
            'Verificando tu ubicación actual con GPS de alta precisión...',
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        // Obtener nombre y dirección real
        final locationData = await _getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        _setStateSafe(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _locationMessage =
              'Perfecto. Tu ubicación ha sido verificada y está lista para solicitar servicio';

          _currentLocationName = locationData.name;
          _currentLocationAddress = locationData.address;

          // Configurar origen por defecto con nombre + dirección real
          _selectedOrigin = TripLocation.currentLocation(
            lat: position.latitude,
            lng: position.longitude,
            name: _currentLocationName,
            address: _currentLocationAddress,
          );
          _originController.removeListener(_onOriginChanged);
          _originController.text = _currentLocationName;
          _originController.addListener(_onOriginChanged);

          // Agregar marcador de ubicación del usuario si no hay ruta
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

        // Cargar conductores disponibles
        _loadAvailableDrivers();
      }
    } catch (e) {
      if (mounted) {
        _setStateSafe(() {
          _isLoadingLocation = false;
          _locationMessage = 'Error al obtener ubicación';
        });
      }
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
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _destinationFocusNode.requestFocus();
  }

  Future<void> _minimizeSheet() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      _sheetMinSize,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openQuickRequestFlow() async {
    await _expandSheet();
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
    _setStateSafe(() {
      _selectedDestination = destination;
      _destinationController.text = destination.name;
      _isSearchingDestination = false;
      _destinationPredictions = [];
    });
    await _saveRecentDestination(destination);
    if (_selectedOrigin != null) {
      await _drawRoute();
    }
  }

  _SheetVisualState _sheetStateFromExtent(double extent) {
    final distMin = (extent - _sheetMinSize).abs();
    final distMid = (extent - _sheetMidSize).abs();
    final distMax = (extent - _sheetMaxSize).abs();

    if (distMin <= distMid && distMin <= distMax) {
      return _SheetVisualState.compact;
    }
    if (distMid <= distMin && distMid <= distMax) {
      return _SheetVisualState.middle;
    }
    return _SheetVisualState.expanded;
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

  bool _shouldApplySheetFrameUpdate(double nextSize) {
    final delta = (nextSize - _sheetSize).abs();
    if (delta <= 0.02) return false;

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastSheetFrameUpdateAt).inMilliseconds;
    if (elapsedMs < 33) return false;

    _lastSheetFrameUpdateAt = now;
    return true;
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
      _setStateSafe(() {
        _selectedDestination = TripLocation.fromPlaceDetails(
          placeId: prediction.placeId,
          name: details.name,
          address: details.address,
          lat: details.lat,
          lng: details.lng,
        );
        _destinationController.text = prediction.mainText;
        _destinationPredictions = [];
        _isSearchingDestination = false;
      });
      await _saveRecentDestination(_selectedDestination!);

      // Restaurar listener
      _destinationController.addListener(_onDestinationChanged);
    }
  }

  Future<void> _drawRoute() async {
    if (_selectedOrigin == null || _selectedDestination == null) return;

    // Mostrar indicador de carga
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Trazando ruta...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

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

        // Crear polilínea
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

        // Crear marcadores
        final Set<Marker> newMarkers = {};

        // Si el origen es la ubicación actual, usar foto de perfil
        final bool isOriginCurrentLocation =
            _selectedOrigin!.isCurrentLocation ||
            (_currentPosition != null &&
                _selectedOrigin!.lat == _currentPosition!.latitude &&
                _selectedOrigin!.lng == _currentPosition!.longitude);

        // Marcador de origen
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

        // Marcador de destino
        newMarkers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: destinationLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: 'Destino',
              snippet: _selectedDestination!.name,
            ),
            zIndexInt: 5,
          ),
        );

        // Agregar marcadores de conductores si están visibles
        if (_showDrivers) {
          for (var conductor in _conductoresDisponibles.values) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('driver_${conductor.conductorId}'),
                position: LatLng(conductor.lat, conductor.lng),
                icon:
                    _driverMarkerIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                infoWindow: InfoWindow(
                  title: '🚗 ${conductor.nombre}',
                  snippet:
                      '⭐ ${conductor.calificacion.toStringAsFixed(1)} • '
                      '${conductor.vehiculo?.descripcion ?? "Sin vehículo"}',
                ),
                onTap: () => _onDriverMarkerTap(conductor),
                zIndexInt: 1,
              ),
            );
          }
        }

        // Si hay ubicación actual y es diferente al origen, mostrar también la ubicación en tiempo real
        if (_currentPosition != null &&
            !isOriginCurrentLocation &&
            _userMarkerIcon != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              icon: _userMarkerIcon!,
              infoWindow: const InfoWindow(
                title: 'Tu ubicación',
                snippet: 'Ubicación en tiempo real',
              ),
              zIndexInt: 1, // Asegurar que esté encima de otros marcadores
            ),
          );
        }

        _markers = newMarkers;
      });

      // Ajustar cámara
      _fitCameraToBounds(routeInfo.polylinePoints);

      // Minimizar el bottom sheet
      if (_isExpanded) {
        _minimizeSheet();
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
    if (_routeInfo == null) return;
    _handleRideConfirmation();
  }

  Future<void> _handleRideConfirmation() async {
    final isDelivery = _serviceType == 'domicilio';
    final pasajeroId =
        Provider.of<AuthProvider>(context, listen: false).idPersona ?? 0;

    if (!mounted) return;
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          WaitingForDriverDialog(isDelivery: isDelivery),
    );

    // Esperar un momento para que el diálogo se muestre completamente
    await Future.delayed(const Duration(milliseconds: 500));

    // 📤 ENVIAR SOLICITUD AL BACKEND
    try {
      final response = isDirectFlow
          ? await _rideRequestService.sendDirectOffer(
              conductorId: selectedConductor!.conductorId,
              pasajeroId: pasajeroId,
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
              distancia: _routeInfo!.distance,
              duracionEstimada: _routeInfo!.duration,
              // Flujo taxímetro: sin negociación de precio en app
              precioOfrecido: 0,
            )
          : await _rideRequestService.requestRide(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
              distance: _routeInfo!.distance,
              distanceValue: _routeInfo!.distanceValue,
              duration: _routeInfo!.duration,
              durationValue: _routeInfo!.durationValue,
              // No se envía precio porque funciona con taxímetro
              serviceType: isDelivery ? 'domicilio' : 'taxi',
            );

      // Cerrar modal de búsqueda
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Esperar para asegurar que el diálogo se cerró
      await Future.delayed(const Duration(milliseconds: 200));

      // Navegar a pantalla de espera del conductor
      if (mounted) {
        // El backend puede devolver 'servicio', 'data' o 'servicio_id'
        int? servicioId;

        if (response['solicitud_id'] != null) {
          servicioId = int.tryParse(response['solicitud_id'].toString());
        } else if (response['servicio'] != null) {
          final servicioData = response['servicio'] as Map<String, dynamic>;
          servicioId = servicioData['id'] as int;
        } else if (response['data'] != null) {
          final servicioData = response['data'] as Map<String, dynamic>;
          servicioId = servicioData['id'] as int;
        } else if (response['servicio_id'] != null) {
          servicioId = response['servicio_id'] as int;
        }

        if (servicioId != null) {
          AppLogger.d(
            '🚀 PASAJERO: Navegando a PasajeroEsperandoConductorScreen',
          );
          AppLogger.d('   Servicio ID: $servicioId');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PasajeroEsperandoConductorScreen(
                servicioId: servicioId!,
                datosServicio: {
                  if (selectedConductor != null)
                    'conductor_id': selectedConductor.conductorId,
                  'origen_lat': _selectedOrigin!.lat,
                  'origen_lng': _selectedOrigin!.lng,
                  'origen_address': _selectedOrigin!.address,
                  'destino_lat': _selectedDestination!.lat,
                  'destino_lng': _selectedDestination!.lng,
                  'destino_address': _selectedDestination!.address,
                  'precio_ofrecido': 0,
                  // No se envía precio porque funciona con taxímetro
                },
              ),
            ),
          ).then((result) {
            // Cuando regrese, limpiar selección
            if (mounted) {
              _setStateSafe(() {
                _selectedDirectDriver = null;
                _selectedOrigin = null;
                _selectedDestination = null;
                _routeInfo = null;
                _polylines.clear();
                _markers.clear();
                _originController.clear();
                _destinationController.clear();
              });
            }
          });
        } else {
          AppLogger.d('⚠️ No se pudo obtener servicio_id de la respuesta');
          AppLogger.d('   Response completo: $response');
        }
      }
    } catch (e) {
      // Error al enviar solicitud - cerrar modal
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Esperar para asegurar que el diálogo se cerró
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _onDriverMarkerTap(Conductor conductor) async {
    _setStateSafe(() {
      _selectedDirectDriver = conductor;
    });

    _scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: Text('Conductor seleccionado: ${conductor.nombre}'),
        duration: const Duration(seconds: 2),
      ),
    );

    final canSendDirectNow =
        _selectedOrigin != null &&
        _selectedDestination != null &&
        _routeInfo != null;

    if (!canSendDirectNow) {
      return;
    }

    await _handleRideConfirmation();
  }

  // ========== MÉTODOS DE PUSHER - CONTRAOFERTAS ==========

  /// Configura la conexión a Pusher para recibir la confirmación de solicitud creada
  Future<void> _setupPusherRequestConfirmation() async {
    try {
      AppLogger.d('🚀 Configurando Pusher para confirmación de solicitudes...');

      // Suscribirse al canal de solicitudes-servicio (conexión secundaria)
      await PusherService.subscribeSecondary('solicitudes-servicio');

      // Registrar el handler para nueva solicitud
      PusherService.registerEventHandlerSecondary(
        'solicitudes-servicio:nueva-solicitud',
        _manejarNuevaSolicitud,
      );

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
