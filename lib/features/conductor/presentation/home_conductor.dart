import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/conductor/widgets/vehiculo_selection_sheet.dart';
import 'package:intellitaxi/features/conductor/widgets/documentos_alert_dialog.dart';

class HomeConductor extends StatefulWidget {
  final List<dynamic> stories;

  const HomeConductor({super.key, required this.stories});

  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Estableciendo conexión satelital para rastreo en tiempo real...';
  bool _isOnline = false;
  Brightness? _lastBrightness;

  // Servicio y datos del conductor
  final ConductorService _conductorService = ConductorService();
  VehiculoConductor? _vehiculoSeleccionado;
  List<VehiculoConductor> _vehiculosDisponibles = [];
  TurnoActivo? _turnoActivo;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _cargarVehiculos();
    _cargarTurnoActual();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = Theme.of(context).brightness;

    // Si el tema cambió y el mapa está cargado, actualizar el estilo
    if (_lastBrightness != null &&
        _lastBrightness != currentBrightness &&
        _mapController != null) {
      _setMapStyle(_mapController!);
    }

    _lastBrightness = currentBrightness;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = 'Verificando permisos...';
    });

    // Verificar y solicitar permisos
    bool permissionGranted = await _checkAndRequestPermissions();

    if (!permissionGranted) {
      setState(() {
        _isLoadingLocation = false;
        _locationMessage = 'Permisos de ubicación denegados';
      });
      _showPermissionDialog();
      return;
    }

    // Obtener ubicación actual
    await _getCurrentLocation();
  }

  Future<bool> _checkAndRequestPermissions() async {
    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Los servicios de ubicación están deshabilitados';
      });
      return false;
    }

    // Verificar el permiso actual
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Solicitar permiso
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Los permisos están permanentemente denegados
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _locationMessage =
            'Estableciendo conexión satelital para rastreo en tiempo real...';
      });

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
        _locationMessage =
            'Sistema GPS activo. Estás visible para pasajeros cercanos';
      });

      // Mover la cámara a la ubicación actual
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
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationMessage = 'Error al obtener ubicación: $e';
      });
    }
  }

  Future<void> _setMapStyle(GoogleMapController controller) async {
    // Verificar que el widget está montado antes de acceder al contexto
    if (!mounted) return;

    // Detectar el tema actual
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    try {
      await controller.setMapStyle(
        isDarkMode ? MapStyles.darkMapStyle : MapStyles.lightMapStyle,
      );
    } catch (e) {
      // Ignora si hay error al aplicar el estilo
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos de Ubicación'),
        content: const Text(
          'Esta aplicación necesita acceso a tu ubicación para mostrarte en el mapa y recibir solicitudes de viaje. Por favor, habilita los permisos de ubicación en la configuración.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Abrir Configuración'),
          ),
        ],
      ),
    );
  }

  /// Carga los vehículos disponibles del conductor
  Future<void> _cargarVehiculos() async {
    try {
      final vehiculos = await _conductorService.getVehiculosConductor();
      setState(() {
        _vehiculosDisponibles = vehiculos;
      });
    } catch (e) {
      print('⚠️ Error cargando vehículos: $e');
    }
  }

  /// Carga el turno actual del conductor si existe
  Future<void> _cargarTurnoActual() async {
    try {
      final turno = await _conductorService.getTurnoActivo();

      if (turno != null && mounted) {
        setState(() {
          _turnoActivo = turno;
          // Si el turno tiene vehículo, asignarlo
          if (turno.vehiculo != null) {
            _vehiculoSeleccionado = turno.vehiculo;
          }
          // ✅ Si hay turno activo, el conductor debe estar en línea
          _isOnline = turno.estaActivo;
        });

        // Guardar turno en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('turno_activo_id', turno.id);
        await prefs.setInt('turno_vehiculo_id', turno.idVehiculo);
        await prefs.setString('turno_fecha', turno.fechaTurno);
        await prefs.setString('turno_hora_inicio', turno.horaInicio);

        print(
          '✅ Turno activo cargado: ID ${turno.id}, Vehículo: ${turno.vehiculo?.placa ?? "N/A"}',
        );
      }
    } catch (e) {
      print('⚠️ Error cargando turno actual: $e');
    }
  }

  /// Inicia un turno con el vehículo seleccionado
  Future<bool> _iniciarTurno(int idVehiculo) async {
    if (!mounted) return false;

    // Guardar referencia al messenger antes de operaciones asíncronas
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Mostrar loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      final turno = await _conductorService.iniciarTurno(idVehiculo);

      // Guardar turno en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('turno_activo_id', turno.id);
      await prefs.setInt('turno_vehiculo_id', turno.idVehiculo);
      await prefs.setString('turno_fecha', turno.fechaTurno);
      await prefs.setString('turno_hora_inicio', turno.horaInicio);

      if (mounted) {
        setState(() {
          _turnoActivo = turno;
        });
      }

      // Cerrar loading
      if (mounted) navigator.pop();

      return true;
    } catch (e) {
      print('⚠️ Error iniciando turno: $e');

      // Cerrar loading
      if (mounted) navigator.pop();

      // Mostrar error usando la referencia guardada
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al iniciar turno: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  /// Finaliza el turno activo
  Future<void> _finalizarTurno() async {
    if (_turnoActivo == null || !mounted) return;

    // Guardar referencia al messenger antes de operaciones asíncronas
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _conductorService.finalizarTurno(_turnoActivo!.id);

      // Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('turno_activo_id');
      await prefs.remove('turno_vehiculo_id');
      await prefs.remove('turno_fecha');
      await prefs.remove('turno_hora_inicio');

      if (mounted) {
        setState(() {
          _turnoActivo = null;
          _vehiculoSeleccionado = null;
          _isOnline = false;
        });
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Turno finalizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('⚠️ Error finalizando turno: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al finalizar turno: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Verifica documentos del conductor y muestra alertas
  Future<void> _verificarDocumentos() async {
    try {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;

      if (userId == null) return;

      final resultado = await _conductorService.verificarDocumentos(userId);
      final vencidos = resultado['vencidos'] ?? [];
      final porVencer = resultado['porVencer'] ?? [];

      if (vencidos.isNotEmpty || porVencer.isNotEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => DocumentosAlertDialog(
            documentosVencidos: vencidos,
            documentosPorVencer: porVencer,
          ),
        );
      }
    } catch (e) {
      print('⚠️ Error verificando documentos: $e');
    }
  }

  /// Muestra el selector de vehículo
  Future<void> _mostrarSelectorVehiculo() async {
    if (!mounted) return;

    // Guardar referencia al messenger antes de operaciones asíncronas
    final messenger = ScaffoldMessenger.of(context);

    if (_vehiculosDisponibles.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No tienes vehículos asignados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VehiculoSelectionSheet(
        vehiculos: _vehiculosDisponibles,
        onVehiculoSelected: (vehiculo) async {
          // Primero iniciar el turno
          final turnoIniciado = await _iniciarTurno(vehiculo.id);

          if (turnoIniciado && mounted) {
            setState(() {
              _vehiculoSeleccionado = vehiculo;
              // ✅ Activar el botón cuando se inicia el turno
              _isOnline = true;
            });

            messenger.showSnackBar(
              SnackBar(
                content: Text('Turno iniciado con vehículo ${vehiculo.placa}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Verificar documentos después de iniciar turno
            _verificarDocumentos();
          }
        },
      ),
    );
  }

  /// Cambia el estado del conductor (online/offline)
  Future<void> _cambiarEstadoConductor() async {
    if (!_isOnline) {
      // Activándose: debe seleccionar vehículo primero
      if (_vehiculoSeleccionado == null) {
        await _mostrarSelectorVehiculo();
        if (_vehiculoSeleccionado != null && _turnoActivo != null) {
          setState(() {
            _isOnline = true;
          });
        }
      } else {
        setState(() {
          _isOnline = true;
        });
      }
    } else {
      // Desactivándose: finalizar turno
      await _finalizarTurno();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mapa de Google Maps
        _currentPosition == null
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey.shade50, Colors.white],
                  ),
                ),
                child: Center(
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
                              children: const [
                                Icon(Icons.refresh_rounded, size: 22),
                                SizedBox(width: 10),
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
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  _setMapStyle(controller);
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('current_location'),
                    position: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    infoWindow: const InfoWindow(
                      title: 'Tu ubicación',
                      snippet: 'Estás aquí',
                    ),
                  ),
                },
              ),

        // Botón de estado del conductor (inferior centro)
        if (_currentPosition != null)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                onTap: _cambiarEstadoConductor,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isOnline
                          ? [AppColors.accent, Colors.orangeAccent]
                          : [Colors.grey.shade400, Colors.grey.shade600],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _isOnline
                            ? AppColors.accent.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isOnline ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'En Línea' : 'Desconectado',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_vehiculoSeleccionado != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _vehiculoSeleccionado!.placa,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Botón de recarga de ubicación
        if (_currentPosition != null)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
      ],
    );
  }
}
