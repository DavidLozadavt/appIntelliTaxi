import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/conductor/widgets/vehiculo_selection_sheet.dart';
import 'package:intellitaxi/features/conductor/widgets/documentos_alert_dialog.dart';
import 'package:intellitaxi/features/conductor/widgets/solicitud_servicio_card.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';

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

  // Solicitudes de servicio
  List<Map<String, dynamic>> _solicitudesActivas = [];
  Map<String, Timer> _timersExpiacion = {};
  bool _suscritoAPusher = false;

  // Servicio activo
  ServicioActivo? _servicioActivo;

  // Audio player para notificaciones
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _cargarVehiculos();
    _cargarTurnoActual();
    _cargarServicioActivo();
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
    _audioPlayer.dispose();
    // Cancelar todos los timers
    for (var timer in _timersExpiacion.values) {
      timer.cancel();
    }
    _timersExpiacion.clear();
    _desconectarPusher();
    super.dispose();
  }

  /// Conecta a Pusher y se suscribe al canal de solicitudes
  Future<void> _conectarPusher() async {
    try {
      if (_suscritoAPusher) {
        print('⚠️ Ya está suscrito a solicitudes-servicio');
        return;
      }

      print('🔌 Suscribiéndose al canal de solicitudes...');

      // Registrar el handler para el evento nueva-solicitud
      PusherService.registerEventHandlerSecondary(
        'solicitudes-servicio:nueva-solicitud',
        _manejarNuevaSolicitud,
      );

      // Suscribirse al canal usando la instancia secundaria
      await PusherService.subscribeSecondary('solicitudes-servicio');

      _suscritoAPusher = true;
      print(
        '✅ Suscrito al canal: solicitudes-servicio (evento: nueva-solicitud)',
      );
    } catch (e) {
      print('⚠️ Error suscribiéndose a Pusher: $e');
    }
  }

  /// Desconecta Pusher y se desuscribe
  Future<void> _desconectarPusher() async {
    try {
      if (!_suscritoAPusher) return;

      // Desuscribirse del canal
      await PusherService.unsubscribeSecondary('solicitudes-servicio');

      // Eliminar el handler
      PusherService.unregisterEventHandlerSecondary(
        'solicitudes-servicio:nueva-solicitud',
      );

      _suscritoAPusher = false;
      print('🔌 Desuscrito de solicitudes-servicio');
    } catch (e) {
      print('⚠️ Error desconectando Pusher: $e');
    }
  }

  /// Maneja la recepción de una nueva solicitud
  void _manejarNuevaSolicitud(dynamic data) {
    print('🚕 _manejarNuevaSolicitud llamado');
    print('📦 Tipo de datos: ${data.runtimeType}');
    print('📦 Datos recibidos: $data');

    if (!mounted) {
      print('⚠️ Widget no montado, ignorando solicitud');
      return;
    }

    try {
      Map<String, dynamic> solicitud;

      // Manejar diferentes tipos de datos
      if (data is String) {
        // Si viene como JSON string, parsearlo
        final Map<String, dynamic> parsed = Map<String, dynamic>.from(
          const JsonDecoder().convert(data) as Map,
        );
        solicitud = parsed;
      } else if (data is Map) {
        solicitud = Map<String, dynamic>.from(data);
      } else {
        print('⚠️ Tipo de datos no soportado: ${data.runtimeType}');
        return;
      }

      // Extraer el ID del servicio de diferentes ubicaciones posibles
      // Prioridad: servicio_id directo > data.id > solicitud_id
      final dynamic servicioIdValue =
          solicitud['servicio_id'] ??
          solicitud['data']?['id'] ??
          solicitud['id'] ??
          solicitud['solicitud_id'];

      String solicitudId;
      bool esIdTemporal = false;

      if (servicioIdValue == null || servicioIdValue.toString() == 'null') {
        // ⚠️ IMPORTANTE: Si no hay ID real del backend, NO mostrar la solicitud
        print('⚠️ Solicitud recibida sin servicio_id válido.');
        print('📦 Estructura recibida: ${solicitud.keys.toList()}');
        print(
          '💡 El backend debe enviar servicio_id o data.id en el evento de Pusher.',
        );
        return; // No procesar solicitudes sin ID válido
      } else {
        solicitudId = servicioIdValue.toString();
        esIdTemporal = solicitudId.startsWith('temp_');
        print('✅ Solicitud con ID válido: $solicitudId');

        if (esIdTemporal) {
          print(
            '⚠️ ID temporal detectado. Esta solicitud no se podrá aceptar.',
          );
          return; // No procesar solicitudes con ID temporal
        }
      }

      // Actualizar la estructura de la solicitud para incluir solicitud_id
      // para mantener compatibilidad con el resto del código
      solicitud['solicitud_id'] = solicitudId;

      // Si la información está anidada en 'data', copiarla al nivel superior
      if (solicitud.containsKey('data') && solicitud['data'] is Map) {
        final Map<String, dynamic> nestedData = solicitud['data'];

        // Copiar campos importantes del nivel data al nivel superior
        solicitud['origen_lat'] = nestedData['origen_lat'];
        solicitud['origen_lng'] = nestedData['origen_lng'];
        solicitud['origen'] =
            nestedData['origen_address'] ?? nestedData['origen_name'];
        solicitud['destino_lat'] = nestedData['destino_lat'];
        solicitud['destino_lng'] = nestedData['destino_lng'];
        solicitud['destino'] =
            nestedData['destino_address'] ?? nestedData['destino_name'];
        solicitud['distancia_metros'] = nestedData['distancia_metros'];
        solicitud['distancia_texto'] = nestedData['distancia_texto'];
        solicitud['duracion_segundos'] = nestedData['duracion_segundos'];
        solicitud['duracion_texto'] = nestedData['duracion_texto'];
        solicitud['precio_estimado'] = nestedData['precio_estimado'];
        solicitud['tipo_servicio'] = nestedData['tipo_servicio'];
        solicitud['clase_vehiculo'] = nestedData['tipo_servicio'] ?? 'taxi';

        print('✅ Datos anidados extraídos correctamente');
      } else {
        // Estructura directa del evento de Pusher
        // Los datos ya están en el nivel superior, solo asegurar clase_vehiculo
        if (!solicitud.containsKey('clase_vehiculo') ||
            solicitud['clase_vehiculo'] == null) {
          solicitud['clase_vehiculo'] =
              solicitud['tipo_servicio'] ?? 'standard';
        }
        print('✅ Usando estructura directa del evento de Pusher');
      }

      // Asegurarse de que pasajero_nombre exista
      if (!solicitud.containsKey('pasajero_nombre') ||
          solicitud['pasajero_nombre'] == null) {
        solicitud['pasajero_nombre'] = 'Pasajero';
      }

      // Logs de verificación
      print('📋 Solicitud procesada:');
      print('   ID: ${solicitud['solicitud_id']}');
      print('   Pasajero: ${solicitud['pasajero_nombre']}');
      print('   Origen: ${solicitud['origen']}');
      print('   Destino: ${solicitud['destino']}');
      print('   Precio: ${solicitud['precio_estimado']}');
      print('   Clase: ${solicitud['clase_vehiculo']}');

      // Verificar si ya existe esta solicitud
      if (_solicitudesActivas.any((s) => s['solicitud_id'] == solicitudId)) {
        print('⚠️ Solicitud $solicitudId ya está en la lista');
        return;
      }

      // Reproducir sonido de notificación
      _reproducirSonidoNotificacion();

      setState(() {
        _solicitudesActivas.add(solicitud);
      });

      // Crear timer de 30 segundos para expirar la solicitud
      _timersExpiacion[solicitudId] = Timer(const Duration(seconds: 30), () {
        _expirarSolicitud(solicitudId);
      });

      print(
        '🎉 Tarjeta de solicitud mostrada (${_solicitudesActivas.length} activas)',
      );
    } catch (e) {
      print('⚠️ Error procesando solicitud: $e');
    }
  }

  /// Reproduce el sonido de notificación
  Future<void> _reproducirSonidoNotificacion() async {
    try {
      await _audioPlayer.play(AssetSource('sound/nuevaoferta.mp3'));
      print('🔊 Sonido de notificación reproducido');
    } catch (e) {
      print('⚠️ Error reproduciendo sonido: $e');
    }
  }

  /// Expira una solicitud después del timer
  void _expirarSolicitud(String solicitudId) {
    print('⏱️ Solicitud $solicitudId expirada');
    _eliminarSolicitud(solicitudId);
  }

  /// Elimina una solicitud de la lista
  void _eliminarSolicitud(String solicitudId) {
    // Cancelar timer si existe
    _timersExpiacion[solicitudId]?.cancel();
    _timersExpiacion.remove(solicitudId);

    setState(() {
      _solicitudesActivas.removeWhere((s) => s['solicitud_id'] == solicitudId);
    });

    print(
      '🗑️ Solicitud eliminada: $solicitudId (${_solicitudesActivas.length} restantes)',
    );
  }

  /// Acepta la solicitud de servicio
  void _aceptarSolicitud(String solicitudId) async {
    final solicitud = _solicitudesActivas.firstWhere(
      (s) => s['solicitud_id'] == solicitudId,
      orElse: () => {},
    );

    if (solicitud.isEmpty) return;

    // Obtener datos necesarios
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conductorId = authProvider.user?.id;

    if (conductorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo identificar al conductor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final precioEstimado =
        double.tryParse(solicitud['precio_estimado']?.toString() ?? '0') ?? 0.0;

    // Controladores para el diálogo
    final precioController = TextEditingController(
      text: precioEstimado.toStringAsFixed(0),
    );
    final mensajeController = TextEditingController(text: 'Voy en camino');

    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceptar Solicitud'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pasajero: ${solicitud['pasajero_nombre']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Origen: ${solicitud['origen']}'),
              const SizedBox(height: 4),
              Text('Destino: ${solicitud['destino']}'),
              const Divider(height: 24),
              const Text(
                'Precio Ofertado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: precioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 27000',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mensaje para el pasajero (opcional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mensajeController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Voy en camino, llego en 5 minutos',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Aceptar Servicio'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Llamar al servicio
      final precioOfertado =
          double.tryParse(precioController.text) ?? precioEstimado;
      final mensaje = mensajeController.text.trim();

      final response = await _conductorService.aceptarSolicitud(
        servicioId: solicitudId,
        precioOfertado: precioOfertado,
        mensaje: mensaje.isEmpty ? null : mensaje,
      );

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      // Mostrar éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Servicio aceptado: ${solicitud['pasajero_nombre']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Eliminar solicitud de la lista
      _eliminarSolicitud(solicitudId);

      print('✅ Solicitud $solicitudId aceptada exitosamente');

      // Actualizar el estado para mostrar el servicio activo en el mismo mapa
      if (mounted && response['servicio'] != null) {
        try {
          final servicioData = response['servicio'] as Map<String, dynamic>;
          final servicio = ServicioActivo.fromJson(servicioData);

          setState(() {
            _servicioActivo = servicio;
          });

          // Guardar en SharedPreferences
          await _guardarServicioActivo(servicio);

          // Actualizar el mapa para mostrar la ruta al punto de recogida
          _actualizarMapaConServicio(servicio);
        } catch (e) {
          print('⚠️ Error procesando servicio activo: $e');
        }
      }
    } catch (e) {
      // Cerrar loading
      if (mounted) Navigator.pop(context);

      // Mostrar error con el mensaje del backend
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      print('⚠️ Error al aceptar solicitud: $e');
    } finally {
      // Limpiar controladores
      precioController.dispose();
      mensajeController.dispose();
    }
  }

  /// Rechaza la solicitud de servicio
  void _rechazarSolicitud(String solicitudId) {
    print('❌ Solicitud rechazada: $solicitudId');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud rechazada'),
        backgroundColor: Colors.red,
      ),
    );

    _eliminarSolicitud(solicitudId);
  }

  /// Guarda el servicio activo en SharedPreferences
  Future<void> _guardarServicioActivo(ServicioActivo servicio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final servicioJson = json.encode({
        'id': servicio.id,
        'fechaServicio': servicio.fechaServicio,
        'idActivationCompanyUser': servicio.idActivationCompanyUser,
        'idEmpresa': servicio.idEmpresa,
        'idEstado': servicio.idEstado,
        'origenServicio': servicio.origenServicio,
        'origen_lat': servicio.origenLat,
        'origen_lng': servicio.origenLng,
        'origen_address': servicio.origenAddress,
        'origen_name': servicio.origenName,
        'destino_lat': servicio.destinoLat,
        'destino_lng': servicio.destinoLng,
        'destino_address': servicio.destinoAddress,
        'destino_name': servicio.destinoName,
        'precio_estimado': servicio.precioEstimado,
        'tipo_servicio': servicio.tipoServicio,
        'conductor_id': servicio.conductorId,
        'estado': {'id': servicio.estado.id, 'estado': servicio.estado.estado},
      });
      await prefs.setString('servicio_activo_conductor', servicioJson);
      print('💾 Servicio activo guardado');
    } catch (e) {
      print('⚠️ Error guardando servicio activo: $e');
    }
  }

  /// Carga el servicio activo desde SharedPreferences
  Future<void> _cargarServicioActivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final servicioJson = prefs.getString('servicio_activo_conductor');

      if (servicioJson != null) {
        final servicioData = json.decode(servicioJson);
        final servicio = ServicioActivo.fromJson(servicioData);

        // Solo cargar si el servicio sigue activo (no finalizado ni cancelado)
        if (servicio.isActivo) {
          setState(() {
            _servicioActivo = servicio;
          });
          _actualizarMapaConServicio(servicio);
          print('✅ Servicio activo recuperado: ${servicio.id}');
        } else {
          // Si está finalizado, limpiar
          await _limpiarServicioActivo();
        }
      }
    } catch (e) {
      print('⚠️ Error cargando servicio activo: $e');
    }
  }

  /// Limpia el servicio activo de SharedPreferences
  Future<void> _limpiarServicioActivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('servicio_activo_conductor');
      print('🗑️ Servicio activo limpiado');
    } catch (e) {
      print('⚠️ Error limpiando servicio activo: $e');
    }
  }

  /// Actualiza el mapa para mostrar el servicio activo
  void _actualizarMapaConServicio(ServicioActivo servicio) {
    if (_mapController == null) return;

    // Calcular bounds para incluir origen (conductor) y destino (pasajero)
    final bounds = LatLngBounds(
      southwest: LatLng(
        servicio.origenLat < servicio.destinoLat
            ? servicio.origenLat
            : servicio.destinoLat,
        servicio.origenLng < servicio.destinoLng
            ? servicio.origenLng
            : servicio.destinoLng,
      ),
      northeast: LatLng(
        servicio.origenLat > servicio.destinoLat
            ? servicio.origenLat
            : servicio.destinoLat,
        servicio.origenLng > servicio.destinoLng
            ? servicio.origenLng
            : servicio.destinoLng,
      ),
    );

    // Animar cámara a los bounds
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
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

        // Conectar a Pusher si el turno está activo
        if (turno.estaActivo) {
          await _conectarPusher();
        }

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

      // Obtener ubicación actual del conductor
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        print(
          '📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}',
        );
      } catch (e) {
        print('⚠️ No se pudo obtener ubicación GPS: $e');
        // Continuar sin ubicación si falla
      }

      // Iniciar turno con ubicación si está disponible
      final turno = await _conductorService.iniciarTurno(
        idVehiculo,
        lat: position?.latitude,
        lng: position?.longitude,
      );

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

      // Conectar a Pusher al iniciar turno
      await _conectarPusher();

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

      // Desconectar de Pusher
      await _desconectarPusher();

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
        if (_currentPosition != null && _servicioActivo == null)
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

        // Tarjetas flotantes de solicitudes de servicio (scrolleable)
        if (_solicitudesActivas.isNotEmpty)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            bottom: 100,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _solicitudesActivas.length,
              itemBuilder: (context, index) {
                final solicitud = _solicitudesActivas[index];
                final solicitudId = solicitud['solicitud_id'] as String;

                return Dismissible(
                  key: Key(solicitudId),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) {
                    _eliminarSolicitud(solicitudId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solicitud descartada'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SolicitudServicioCard(
                      solicitud: solicitud,
                      onAceptar: () => _aceptarSolicitud(solicitudId),
                      onRechazar: () => _rechazarSolicitud(solicitudId),
                    ),
                  ),
                );
              },
            ),
          ),

        // Panel de servicio activo (reemplaza las solicitudes cuando hay un servicio aceptado)
        if (_servicioActivo != null)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCard
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado del servicio
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(_servicioActivo!.idEstado),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _servicioActivo!.estado.estado.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Información del pasajero
                  Row(
                    children: [
                      const CircleAvatar(radius: 25, child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pasajero',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${_servicioActivo!.idActivationCompanyUser}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: Llamar al pasajero
                        },
                        icon: const Icon(Icons.phone, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Origen y destino
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 30,
                            color: Colors.grey.shade300,
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recoger en:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _servicioActivo!.origenName ?? 'Ubicación origen',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Destino:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _servicioActivo!.destinoName ??
                                  'Ubicación destino',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción según el estado
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // TODO: Implementar cambio de estado del servicio
                            // Por ahora, si es finalizado, limpiar
                            if (_servicioActivo!.estado.id == 5) {
                              // Simular finalización
                              await _limpiarServicioActivo();
                              setState(() {
                                _servicioActivo = null;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🏁 Servicio finalizado'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _getButtonText(_servicioActivo!.estado.id),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getButtonText(int estadoId) {
    switch (estadoId) {
      case 2: // Aceptado
        return 'Iniciar viaje al origen';
      case 3: // En camino
        return 'Ya llegué';
      case 4: // Llegué
        return 'Iniciar viaje';
      case 5: // En curso
        return 'Finalizar viaje';
      default:
        return 'Continuar';
    }
  }

  Color _getEstadoColor(int estadoId) {
    switch (estadoId) {
      case 1: // Pendiente
        return AppColors.secondary;
      case 2: // Aceptado
        return AppColors.primary;
      case 3: // En camino
        return AppColors.accent;
      case 4: // Llegué
        return AppColors.accent;
      case 5: // En curso
        return AppColors.green;
      case 6: // Finalizado
        return AppColors.grey;
      case 7: // Cancelado
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }
}
