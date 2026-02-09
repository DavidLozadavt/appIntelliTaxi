import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';
import 'package:intellitaxi/features/rides/services/places_service.dart';
import 'package:intellitaxi/features/rides/services/ride_request_service.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/rides/widgets/driver_offer_card.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/features/rides/services/active_service_manager.dart';
import 'package:intellitaxi/features/rides/presentation/active_service_screen.dart';
import 'package:intellitaxi/features/rides/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/rides/data/conductor_model.dart';
import 'package:intellitaxi/features/rides/services/conductores_service.dart';
import 'package:intellitaxi/features/rides/services/pusher_conductores_service.dart';
import 'package:intellitaxi/features/pasajero/widgets/location_search_field.dart';
import 'package:intellitaxi/features/pasajero/widgets/service_type_selector.dart';
import 'package:intellitaxi/features/pasajero/widgets/route_info_card.dart';
import 'package:intellitaxi/features/pasajero/widgets/ride_confirmation_dialog.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/shared/widgets/standard_button.dart';
import 'package:intellitaxi/features/pasajero/widgets/waiting_for_driver_dialog.dart';

class HomePasajero extends StatefulWidget {
  final List<dynamic> stories;

  const HomePasajero({super.key, required this.stories});

  @override
  State<HomePasajero> createState() => _HomePasajeroState();
}

class _HomePasajeroState extends State<HomePasajero>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Verificando tu ubicación actual con GPS de alta precisión...';
  Brightness? _lastBrightness;
  Brightness _currentBrightness = Brightness.light;

  // Para el bottom sheet animado
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  bool _isExpanded = false;
  final double _minHeight = 0.15; // 15% para modo minimizado
  final double _maxHeight = 0.7; // 60% para modo expandido

  // Para las búsquedas
  final PlacesService _placesService = PlacesService();
  final RoutesService _routesService = RoutesService();
  final RideRequestService _rideRequestService = RideRequestService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  TripLocation? _selectedOrigin;
  TripLocation? _selectedDestination;
  RouteInfo? _routeInfo;

  List<PlacePrediction> _originPredictions = [];
  List<PlacePrediction> _destinationPredictions = [];
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  // Tipo de servicio: 'taxi' o 'domicilio'
  String _serviceType = 'taxi';

  // Marcadores y polilíneas
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _userMarkerIcon;

  // Para contraofertas de conductores
  Map<String, dynamic>? _currentOffer;
  bool _showOffer = false;

  // Gestor de servicio activo
  final ActiveServiceManager _activeServiceManager = ActiveServiceManager();

  // Referencia segura al ScaffoldMessenger
  ScaffoldMessengerState? _scaffoldMessenger;

  // Conductores disponibles
  final ConductoresService _conductoresService = ConductoresService();
  PusherConductoresService? _pusherConductoresService;
  Map<int, Conductor> _conductoresDisponibles = {};
  BitmapDescriptor? _driverMarkerIcon;
  bool _showDrivers = true; // Toggle para mostrar/ocultar conductores

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

    // Animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _heightAnimation = Tween<double>(begin: _minHeight, end: _maxHeight)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

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

    final currentBrightness = Theme.of(context).brightness;
    _currentBrightness = currentBrightness;

    if (_lastBrightness != null &&
        _lastBrightness != currentBrightness &&
        _mapController != null) {
      _setMapStyle(_mapController!);
    }
    _lastBrightness = currentBrightness;
  }

  @override
  void dispose() {
    // Limpiar callbacks PRIMERO para evitar llamadas con context inválido
    _activeServiceManager.onServiceUpdated = null;
    _activeServiceManager.onServiceCompleted = null;

    // Limpiar referencia al ScaffoldMessenger
    _scaffoldMessenger = null;

    // Limpiar ActiveServiceManager
    _activeServiceManager.cleanup();

    // Desuscribirse de Pusher
    PusherService.unsubscribeSecondary('ofertas-globales');
    PusherService.unregisterEventHandlerSecondary(
      'ofertas-globales:nueva-oferta',
    );

    PusherService.unsubscribeSecondary('solicitudes-servicio');
    PusherService.unregisterEventHandlerSecondary(
      'solicitudes-servicio:nueva-solicitud',
    );

    // Remover listeners de los controladores de texto ANTES de disponer
    _originController.removeListener(_onOriginChanged);
    _destinationController.removeListener(_onDestinationChanged);

    // Desconectar servicio de conductores
    _pusherConductoresService?.disconnect();

    _destinationController.dispose();

    super.dispose();
  }

  // ========== MÉTODOS DE SERVICIO ACTIVO ==========

  /// Verifica si hay un servicio activo al iniciar la app
  Future<void> _checkActiveService() async {
    try {
      print('🔍 Verificando servicio activo al iniciar...');

      final servicio = await _activeServiceManager.getActiveService();

      if (servicio != null && servicio.isActivo) {
        print('✅ Servicio activo encontrado: ${servicio.id}');
        print('📊 Estado: ${servicio.estado.estado}');

        // Navegar a pantalla de servicio activo
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveServiceScreen(
              servicio: servicio,
              onServiceCompleted: () {
                // Cuando el servicio se complete, volver al home
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        );

        // Iniciar polling para actualizar el servicio
        _startServiceTracking(servicio.id);
      } else {
        print('ℹ️ No hay servicio activo');
      }
    } catch (e) {
      print('⚠️ Error verificando servicio activo: $e');
    }
  }

  /// Inicia el tracking del servicio activo
  void _startServiceTracking(int servicioId) {
    // Configurar callbacks
    _activeServiceManager.onServiceUpdated = (servicio) {
      if (!mounted) return;
      print('🔄 Servicio actualizado: ${servicio.estado.estado}');
      // TODO: Actualizar UI si es necesario
    };

    _activeServiceManager.onServiceCompleted = () {
      print('🏁 Servicio completado/cancelado');
      if (!mounted) return;

      // Usar WidgetsBinding para asegurar que se ejecute después del frame actual
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
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

      print('🚗 Configurando Pusher para conductores...');
      print('   🏢 Empresa ID: $idEmpresa');

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

      print('✅ Pusher conductores configurado');
    } catch (e) {
      print('❌ Error configurando Pusher conductores: $e');
    }
  }

  /// Carga los conductores disponibles inicialmente
  Future<void> _loadAvailableDrivers() async {
    if (_currentPosition == null) {
      print('⚠️ No hay posición actual para buscar conductores');
      return;
    }

    try {
      print('🔍 Cargando conductores disponibles...');

      final conductores = await _conductoresService.getConductoresDisponibles(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        radioKm: 10,
      );

      if (!mounted) return;

      setState(() {
        _conductoresDisponibles.clear();
        for (var conductor in conductores) {
          _conductoresDisponibles[conductor.conductorId] = conductor;
        }
      });

      // Actualizar marcadores
      _updateAllDriverMarkers();

      print('✅ ${conductores.length} conductores cargados');
    } catch (e) {
      print('❌ Error cargando conductores: $e');
    }
  }

  /// Actualiza el marcador de un conductor específico
  void _updateDriverMarker(Conductor conductor) {
    if (!_showDrivers) return;

    setState(() {
      _conductoresDisponibles[conductor.conductorId] = conductor;
      _updateAllDriverMarkers();
    });

    print('📍 Marcador actualizado: ${conductor.nombre}');
  }

  /// Elimina el marcador de un conductor
  void _removeDriverMarker(int conductorId) {
    setState(() {
      _conductoresDisponibles.remove(conductorId);
      _updateAllDriverMarkers();
    });

    print('🔴 Conductor removido: $conductorId');
  }

  /// Actualiza todos los marcadores en el mapa
  void _updateAllDriverMarkers() {
    final Set<Marker> newMarkers = {};

    // Agregar marcadores de conductores solo si están visibles
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
                  '${conductor.vehiculo?.descripcion ?? "Sin vehículo"}\n'
                  '📏 ${conductor.distanciaKm != null ? "${conductor.distanciaKm!.toStringAsFixed(2)} km" : ""}',
            ),
            zIndex: 1, // Debajo de otros marcadores
          ),
        );
      }
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
          infoWindow: const InfoWindow(
            title: 'Tú',
            snippet: 'Tu ubicación actual',
          ),
          zIndex: 10, // Encima de todos
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });

    print(
      '🗺️ Marcadores actualizados: ${_conductoresDisponibles.length} conductores, ${newMarkers.length} marcadores totales',
    );
  }

  /// Alterna la visibilidad de los conductores
  void _toggleDriversVisibility() {
    setState(() {
      _showDrivers = !_showDrivers;
      if (_showDrivers) {
        _updateAllDriverMarkers();
      } else {
        // Mantener solo marcadores de ruta
        _markers.removeWhere(
          (marker) => marker.markerId.value.startsWith('driver_'),
        );
      }
    });
  }

  /// Crea el icono del marcador para conductores
  Future<void> _createDriverMarkerIcon() async {
    try {
      // Usar la imagen personalizada desde assets
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/marker.png',
      );

      setState(() => _driverMarkerIcon = icon);
    } catch (e) {
      print('Error creando icono de conductor: $e');
      setState(
        () => _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      );
    }
  }

  /// Crea un marcador personalizado con un icono
  Future<BitmapDescriptor?> _createCustomMarkerIcon({
    required IconData icon,
    required Color color,
    double size = 100,
  }) async {
    try {
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);

      // Dibujar círculo de fondo
      final Paint circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2, circlePaint);

      // Dibujar borde blanco
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

      // Dibujar icono
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.5,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
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
        return BitmapDescriptor.fromBytes(pngBytes);
      }
    } catch (e) {
      print('Error creando icono personalizado: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Mapa de Google Maps
        _currentPosition == null
            ? Center(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.accent.withOpacity(0.05),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animación de ubicación
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isLoadingLocation
                                ? [
                                    AppColors.accent.withOpacity(0.2),
                                    AppColors.accent.withOpacity(0.05),
                                  ]
                                : [
                                    Colors.grey.withOpacity(0.2),
                                    Colors.grey.withOpacity(0.05),
                                  ],
                          ),
                          boxShadow: _isLoadingLocation
                              ? [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.2),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLoadingLocation
                                  ? AppColors.accent.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                            ),
                            child: Center(
                              child: _isLoadingLocation
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 45,
                                          color: AppColors.accent,
                                        ),
                                        SizedBox(
                                          width: 90,
                                          height: 90,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.accent,
                                                ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.location_off_rounded,
                                      size: 45,
                                      color: Colors.grey.shade400,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Título
                      Text(
                        _isLoadingLocation
                            ? 'Conectando GPS'
                            : 'Ubicación no disponible',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Mensaje descriptivo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _locationMessage,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Botón de reintentar
                      if (!_isLoadingLocation) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _initializeLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Reintentar conexión',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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

        // Bottom Sheet Persistente
        if (_currentPosition != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _heightAnimation,
              builder: (context, child) {
                return GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta! < -5 && !_isExpanded) {
                      _toggleSheet();
                    } else if (details.primaryDelta! > 5 && _isExpanded) {
                      _toggleSheet();
                    }
                  },
                  child: Container(
                    height: screenHeight * _heightAnimation.value,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Handle
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

                        // Contenido
                        if (!_isExpanded)
                          _buildMinimizedContent()
                        else
                          Expanded(child: _buildExpandedContent()),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Botón de centrar ubicación
        if (_currentPosition != null)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'center_location',
              onPressed: _centerToCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.deepOrange),
            ),
          ),

        // Botón de limpiar ruta
        if (_routeInfo != null)
          Positioned(
            top: 70,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'clear_route',
              onPressed: _clearRoute,
              backgroundColor: Colors.white,
              child: const Icon(Icons.clear, color: Colors.red),
            ),
          ),

        // Botones de control de conductores
        if (_currentPosition != null && _routeInfo == null)
          Positioned(
            top: 70,
            right: 16,
            child: Column(
              children: [
                // Toggle mostrar/ocultar conductores
                FloatingActionButton.small(
                  onPressed: _toggleDriversVisibility,
                  backgroundColor: _showDrivers ? Colors.green : Colors.grey,
                  heroTag: 'toggle_drivers',
                  child: Icon(
                    _showDrivers ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Recargar conductores
                FloatingActionButton.small(
                  onPressed: _loadAvailableDrivers,
                  backgroundColor: Colors.white,
                  heroTag: 'reload_drivers',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/marker.png',
                        width: 24,
                        height: 24,
                      ),
                      if (_conductoresDisponibles.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${_conductoresDisponibles.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
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
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceType == 'taxi'
                          ? '¿A dónde vas?'
                          : 'Enviar domicilio',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _routeInfo != null
                          ? '${_routeInfo!.distance} • Cobro por taxímetro'
                          : 'Toca para seleccionar destino',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Selector de tipo de servicio
        ServiceTypeSelector(
          selectedType: _serviceType,
          onTypeChanged: (type) {
            setState(() {
              _serviceType = type;
              _clearRoute();
            });
          },
        ),
        const SizedBox(height: 16),

        Text(
          _serviceType == 'taxi' ? '¿A dónde vas?' : '¿Qué necesitas enviar?',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

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
            setState(() {
              _originController.clear();
              _selectedOrigin = null;
              _originPredictions = [];
            });
          },
        ),

        const SizedBox(height: 16),

        // Campo de destino
        LocationSearchField(
          controller: _destinationController,
          label: 'Destino',
          icon: Icons.location_on,
          iconColor: Colors.red,
          predictions: _destinationPredictions,
          isSearching: _isSearchingDestination,
          onSelectPrediction: _selectDestination,
          onClear: () {
            setState(() {
              _destinationController.clear();
              _selectedDestination = null;
              _destinationPredictions = [];
              _clearRoute();
            });
          },
        ),

        const SizedBox(height: 24),

        // Botón de trazar ruta
        if (_selectedOrigin != null &&
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

        // Información de la ruta
        if (_routeInfo != null) ...[
          RouteInfoCard(routeInfo: _routeInfo!),
          const SizedBox(height: 16),

          // Botón de solicitar viaje
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

        const SizedBox(height: 16),

        // Info de búsqueda
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withOpacity(isDark ? 0.5 : 0.3),
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
          setState(() => _userMarkerIcon = icon);
          return;
        }
      }

      // Si no hay foto o falla la carga, usar icono por defecto
      setState(
        () => _userMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    } catch (e) {
      // En caso de error, usar marcador por defecto
      setState(
        () => _userMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    }
  }

  Future<BitmapDescriptor?> _getMarkerIconFromUrl(String imageUrl) async {
    try {
      // Descargar la imagen
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      // Convertir a ui.Image
      final Uint8List imageData = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: 150,
        targetHeight: 150,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      // Crear un canvas para dibujar el marcador circular
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final double size = 150.0;

      // Dibujar sombra exterior
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(
        Offset(size / 2 + 2, size / 2 + 2),
        (size / 2) - 2,
        shadowPaint,
      );

      // Dibujar círculo blanco como borde exterior
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        (size / 2) - 2,
        borderPaint,
      );

      // Guardar estado del canvas
      canvas.save();

      // Recortar la imagen en forma circular
      final Path clipPath = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(size / 2, size / 2),
            radius: (size / 2) - 8,
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
        Rect.fromLTWH(8, 8, size - 16, size - 16),
        Paint()..filterQuality = FilterQuality.high,
      );

      // Restaurar estado del canvas
      canvas.restore();

      // Dibujar borde de color accent (naranja)
      final Paint accentBorderPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        (size / 2) - 5,
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
        return BitmapDescriptor.fromBytes(pngBytes);
      }
    } catch (e) {
      print('Error creando marcador personalizado: $e');
    }
    return null;
  }

  // Obtener dirección desde coordenadas (Geocoding reverso)
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
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
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo dirección: $e');
    }
    return 'Mi ubicación actual';
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = 'Verificando permisos...';
    });

    bool permissionGranted = await _checkAndRequestPermissions();

    if (!permissionGranted) {
      setState(() {
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
      setState(
        () => _locationMessage =
            'Verificando tu ubicación actual con GPS de alta precisión...',
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        // Obtener dirección real
        final address = await _getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _locationMessage =
              'Perfecto. Tu ubicación ha sido verificada y está lista para solicitar servicio';

          // Configurar origen por defecto con dirección real
          _selectedOrigin = TripLocation.currentLocation(
            lat: position.latitude,
            lng: position.longitude,
            address: address,
          );
          _originController.text = address;

          // Agregar marcador de ubicación del usuario si no hay ruta
          if (_markers.isEmpty && _userMarkerIcon != null) {
            _markers = {
              Marker(
                markerId: const MarkerId('user_location'),
                position: LatLng(position.latitude, position.longitude),
                icon: _userMarkerIcon!,
                infoWindow: const InfoWindow(
                  title: 'Tú',
                  snippet: 'Tu ubicación actual',
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
        setState(() {
          _isLoadingLocation = false;
          _locationMessage = 'Error al obtener ubicación';
        });
      }
    }
  }

  Future<void> _setMapStyle(GoogleMapController controller) async {
    if (!mounted) return;
    final isDarkMode = _currentBrightness == Brightness.dark;
    try {
      await controller.setMapStyle(
        isDarkMode ? MapStyles.darkMapStyle : MapStyles.lightMapStyle,
      );
    } catch (e) {
      // Ignorar error
    }
  }

  void _toggleSheet() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onOriginChanged() {
    if (!mounted) return;

    if (_originController.text.isEmpty) {
      setState(() {
        _originPredictions = [];
        _isSearchingOrigin = false;
      });
      return;
    }

    setState(() => _isSearchingOrigin = true);

    _placesService.getAutocompletePredictions(_originController.text).then((
      predictions,
    ) {
      if (mounted) {
        setState(() {
          _originPredictions = predictions;
          _isSearchingOrigin = false;
        });
      }
    });
  }

  void _onDestinationChanged() {
    if (!mounted) return;

    if (_destinationController.text.isEmpty) {
      setState(() {
        _destinationPredictions = [];
        _isSearchingDestination = false;
      });
      return;
    }

    setState(() => _isSearchingDestination = true);

    _placesService.getAutocompletePredictions(_destinationController.text).then(
      (predictions) {
        if (mounted) {
          setState(() {
            _destinationPredictions = predictions;
            _isSearchingDestination = false;
          });
        }
      },
    );
  }

  Future<void> _selectOrigin(PlacePrediction prediction) async {
    // Remover listener temporalmente
    _originController.removeListener(_onOriginChanged);

    final details = await _placesService.getPlaceDetails(prediction.placeId);

    if (details != null && mounted) {
      setState(() {
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

    final details = await _placesService.getPlaceDetails(prediction.placeId);

    if (details != null && mounted) {
      setState(() {
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
      setState(() {
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
            zIndex: 5,
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
                zIndex: 1,
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
              zIndex: 1, // Asegurar que esté encima de otros marcadores
            ),
          );
        }

        _markers = newMarkers;
      });

      // Ajustar cámara
      _fitCameraToBounds(routeInfo.polylinePoints);

      // Minimizar el bottom sheet
      if (_isExpanded) {
        _toggleSheet();
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
    setState(() {
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

    showDialog(
      context: context,
      builder: (context) => RideConfirmationDialog(
        serviceType: _serviceType,
        origin: _selectedOrigin!,
        destination: _selectedDestination!,
        routeInfo: _routeInfo!,
        onConfirm: () => _handleRideConfirmation(),
      ),
    );
  }

  Future<void> _handleRideConfirmation() async {
    final isDelivery = _serviceType == 'domicilio';

    // Cerrar el diálogo de confirmación
    Navigator.pop(context);

    // Esperar un momento para que se complete la animación del cierre
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

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
      final response = await _rideRequestService.requestRide(
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

        if (response['servicio'] != null) {
          final servicioData = response['servicio'] as Map<String, dynamic>;
          servicioId = servicioData['id'] as int;
        } else if (response['data'] != null) {
          final servicioData = response['data'] as Map<String, dynamic>;
          servicioId = servicioData['id'] as int;
        } else if (response['servicio_id'] != null) {
          servicioId = response['servicio_id'] as int;
        }

        if (servicioId != null) {
          print('🚀 PASAJERO: Navegando a PasajeroEsperandoConductorScreen');
          print('   Servicio ID: $servicioId');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PasajeroEsperandoConductorScreen(
                servicioId: servicioId!,
                datosServicio: {
                  'origen_lat': _selectedOrigin!.lat,
                  'origen_lng': _selectedOrigin!.lng,
                  'origen_address': _selectedOrigin!.address,
                  'destino_lat': _selectedDestination!.lat,
                  'destino_lng': _selectedDestination!.lng,
                  'destino_address': _selectedDestination!.address,
                  // No se envía precio porque funciona con taxímetro
                },
              ),
            ),
          ).then((result) {
            // Cuando regrese, limpiar selección
            if (mounted) {
              setState(() {
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
          print('⚠️ No se pudo obtener servicio_id de la respuesta');
          print('   Response completo: $response');
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

  // ========== MÉTODOS DE PUSHER - CONTRAOFERTAS ==========

  /// Configura la conexión a Pusher para recibir la confirmación de solicitud creada
  Future<void> _setupPusherRequestConfirmation() async {
    try {
      print('🚀 Configurando Pusher para confirmación de solicitudes...');

      // Suscribirse al canal de solicitudes-servicio (conexión secundaria)
      await PusherService.subscribeSecondary('solicitudes-servicio');

      // Registrar el handler para nueva solicitud
      PusherService.registerEventHandlerSecondary(
        'solicitudes-servicio:nueva-solicitud',
        _manejarNuevaSolicitud,
      );

      print(
        '✅ Pusher configurado - Esperando confirmación en canal solicitudes-servicio',
      );
    } catch (e) {
      print('❌ Error configurando Pusher: $e');
    }
  }

  /// Maneja la llegada de la confirmación de solicitud creada
  void _manejarNuevaSolicitud(dynamic data) {
    print('🚕 _manejarNuevaSolicitud llamado en PASAJERO');
    print('📦 Tipo de datos: ${data.runtimeType}');
    print('📦 Datos recibidos: $data');

    if (!mounted) {
      print('⚠️ Widget no montado, ignorando solicitud');
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
        print('⚠️ Tipo de datos no soportado: ${data.runtimeType}');
        return;
      }

      print('✅ Datos parseados correctamente');
      print('🔍 Contenido:');
      print('   - servicio_id: ${solicitudData['servicio_id']}');
      print('   - success: ${solicitudData['success']}');
      print('   - message: ${solicitudData['message']}');

      // Verificar que el widget aún esté montado
      if (!mounted) return;

      // Verificar que la solicitud sea para este pasajero
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.idPersona;

      // Obtener el pasajero_id de los datos o del data anidado
      final pasajeroId =
          solicitudData['pasajero_id'] ?? solicitudData['data']?['pasajero_id'];

      print('👤 Usuario actual: $currentUserId, Solicitud para: $pasajeroId');

      if (currentUserId == pasajeroId) {
        print('✅ La solicitud es para este pasajero');

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
        print('⏭️ Solicitud no es para este pasajero, ignorando');
      }
    } catch (e, stackTrace) {
      print('⚠️ Error procesando solicitud: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  /// Configura la conexión a Pusher para recibir contraofertas
  Future<void> _setupPusherOffers() async {
    try {
      print('🚀 Configurando Pusher para ofertas globales...');

      // Suscribirse al canal de ofertas globales (conexión secundaria)
      await PusherService.subscribeSecondary('ofertas-globales');

      // Registrar el handler para nueva oferta
      PusherService.registerEventHandlerSecondary(
        'ofertas-globales:nueva-oferta',
        _handleNewOffer,
      );

      print(
        '✅ Pusher configurado - Esperando ofertas en canal ofertas-globales',
      );
    } catch (e) {
      print('❌ Error configurando Pusher: $e');
    }
  }

  /// Maneja la llegada de una nueva contraoferta
  void _handleNewOffer(dynamic data) {
    print('🎉 ¡Nueva contraoferta recibida!');
    print('📦 Data tipo: ${data.runtimeType}');
    print('📦 Data completa: $data');

    try {
      // Parsear data si viene como string
      Map<String, dynamic> offerData;
      if (data is String) {
        offerData = jsonDecode(data);
      } else {
        offerData = Map<String, dynamic>.from(data);
      }

      print('🔍 Datos parseados:');
      print('   - oferta_id: ${offerData['oferta_id']}');
      print('   - solicitud_id: ${offerData['solicitud_id']}');
      print('   - pasajero_id: ${offerData['pasajero_id']}');
      print('   - conductor_nombre: ${offerData['conductor_nombre']}');
      print('   - precio_ofertado: ${offerData['precio_ofertado']}');

      // Verificar que el widget aún esté montado
      if (!mounted) return;

      // Verificar que la oferta sea para este pasajero
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.idPersona;
      final offerPassengerId = offerData['pasajero_id'];

      print(
        '👤 Usuario actual: $currentUserId, Oferta para: $offerPassengerId',
      );

      if (currentUserId == offerPassengerId) {
        if (!mounted) return;

        setState(() {
          _currentOffer = offerData;
          _showOffer = true;
        });

        print('✅ Oferta mostrada al usuario');

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
        print('⏭️ Oferta no es para este pasajero, ignorando');
      }
    } catch (e, stackTrace) {
      print('❌ Error procesando oferta: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  /// Acepta la contraoferta del conductor
  void _acceptOffer() {
    if (_currentOffer == null) return;

    print('✅ Aceptando oferta: ${_currentOffer!['oferta_id']}');

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

    setState(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }

  /// Rechaza la contraoferta del conductor
  void _rejectOffer() {
    if (_currentOffer == null) return;

    print('❌ Rechazando oferta: ${_currentOffer!['oferta_id']}');

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

    setState(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }

  /// Cierra la oferta sin aceptar ni rechazar
  void _dismissOffer() {
    setState(() {
      _showOffer = false;
      _currentOffer = null;
    });
  }
}
