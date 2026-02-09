import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/rides/widgets/calificacion_dialog.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Pantalla del conductor durante un servicio activo
class ConductorServicioActivoScreen extends StatefulWidget {
  final Map<String, dynamic> servicioData;
  final int conductorId;

  const ConductorServicioActivoScreen({
    super.key,
    required this.servicioData,
    required this.conductorId,
  });

  @override
  State<ConductorServicioActivoScreen> createState() =>
      _ConductorServicioActivoScreenState();
}

class _ConductorServicioActivoScreenState
    extends State<ConductorServicioActivoScreen> {
  GoogleMapController? _mapController;
  final ServicioTrackingService _trackingService = ServicioTrackingService();
  final ServicioPersistenciaService _persistencia =
      ServicioPersistenciaService();
  final ServicioNotificacionForeground _notificacionService =
      ServicioNotificacionForeground();

  late ServicioActivo servicio;
  String? pasajeroNombre;
  String? pasajeroTelefono;
  String? pasajeroEmail;
  String? pasajeroFoto;

  String _estadoActual = 'aceptado';
  Position? _miUbicacion;
  LatLng? _destinoActual;
  final Set<Marker> _markers = {};
  Timer? _ubicacionTimer;

  @override
  void initState() {
    super.initState();
    _parsearDatos();
    _inicializar();
  }

  void _parsearDatos() {
    // Parsear el servicio desde servicioData
    final servicioMap =
        widget.servicioData['servicio'] as Map<String, dynamic>? ??
        widget.servicioData;
    servicio = ServicioActivo.fromJson(servicioMap);

    // Extraer datos del pasajero
    final pasajeroData =
        widget.servicioData['pasajero'] as Map<String, dynamic>?;
    if (pasajeroData != null) {
      pasajeroNombre = pasajeroData['nombre'];
      pasajeroTelefono = pasajeroData['celular'];
      pasajeroEmail = pasajeroData['email'];
      pasajeroFoto = pasajeroData['foto'];
    } else {
      // Fallback: extraer del usuario_pasajero
      final usuarioPasajero =
          widget.servicioData['usuario_pasajero'] as Map<String, dynamic>?;
      if (usuarioPasajero != null) {
        final persona = usuarioPasajero['persona'] as Map<String, dynamic>?;
        if (persona != null) {
          pasajeroNombre =
              '${persona['nombre1'] ?? ''} ${persona['apellido1'] ?? ''}'
                  .trim();
          pasajeroTelefono = persona['celular'];
          pasajeroEmail = persona['email'];
          pasajeroFoto = persona['rutaFotoUrl'];
        }
      }
    }

    // Si no se encontró nombre, usar "Pasajero"
    pasajeroNombre ??= 'Pasajero';

    print('👥 Datos del pasajero cargados:');
    print('   Nombre: $pasajeroNombre');
    print('   Teléfono: $pasajeroTelefono');
    print('   Email: $pasajeroEmail');
  }

  Future<void> _inicializar() async {
    // Inicializar notificaciones
    await _notificacionService.inicializar();

    // Guardar servicio activo
    await _persistencia.guardarServicioActivo(
      servicioId: servicio.id,
      tipo: 'conductor',
      datosServicio: servicio.toJson(),
    );

    // Mostrar notificación persistente
    await _notificacionService.mostrarNotificacionConductor(
      servicioId: servicio.id,
      estado: servicio.estado.estado,
      origen: servicio.origenAddress,
      destino: servicio.destinoAddress,
    );

    // Iniciar seguimiento GPS
    await _trackingService.iniciarSeguimiento(
      servicioId: servicio.id,
      conductorId: widget.conductorId,
    );

    // El destino inicial es el punto de recogida
    setState(() {
      _destinoActual = LatLng(servicio.origenLat, servicio.origenLng);
      _estadoActual = servicio.estado.estado;
    });

    // Obtener ubicación actual
    await _obtenerUbicacionActual();

    // Actualizar ubicación cada 3 segundos para el mapa
    _ubicacionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _obtenerUbicacionActual(),
    );

    _crearMarcadores();
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _miUbicacion = position;
        });
        _actualizarCamara();
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  void _crearMarcadores() {
    setState(() {
      _markers.clear();

      // Marcador del destino actual (origen o destino final)
      _markers.add(
        Marker(
          markerId: const MarkerId('destino_actual'),
          position: _destinoActual!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _estadoActual == 'en_curso'
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: _estadoActual == 'en_curso'
                ? 'Destino Final'
                : 'Punto de Recogida',
            snippet: _estadoActual == 'en_curso'
                ? servicio.destinoAddress
                : servicio.origenAddress,
          ),
        ),
      );
    });
  }

  void _actualizarCamara() {
    if (_mapController == null || _miUbicacion == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_miUbicacion!.latitude, _miUbicacion!.longitude),
          zoom: 16,
          bearing: _miUbicacion!.heading,
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await _trackingService.cambiarEstado(
      servicioId: servicio.id,
      conductorId: widget.conductorId,
      estado: nuevoEstado,
    );

    // Cerrar loading
    if (mounted) Navigator.pop(context);

    if (success) {
      setState(() {
        _estadoActual = nuevoEstado;

        // Si llegó al punto de recogida, cambiar destino al final
        if (nuevoEstado == 'llegue') {
          _destinoActual = LatLng(servicio.destinoLat, servicio.destinoLng);
          _crearMarcadores();
        }
      });

      // Actualizar notificación
      await _notificacionService.actualizarNotificacion(
        servicioId: servicio.id,
        tipo: 'conductor',
        estado: nuevoEstado,
        origen: servicio.origenAddress,
        destino: servicio.destinoAddress,
      );

      // Mostrar snackbar de confirmación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getMensajeEstado(nuevoEstado)),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Si finalizó, detener seguimiento y mostrar calificación
      if (nuevoEstado == 'finalizado') {
        _trackingService.detenerSeguimiento();

        // Cancelar notificación
        await _notificacionService.cancelarNotificacion(
          servicio.id,
          tipo: 'conductor',
        );

        // Limpiar persistencia
        await _persistencia.limpiarServicioActivo();

        // Mostrar diálogo de calificación
        if (mounted) {
          await _mostrarDialogoCalificacion();
          Navigator.pop(context, true); // true indica que finalizó
        }
      }
    } else {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cambiar el estado'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getMensajeEstado(String estado) {
    switch (estado) {
      case 'en_camino':
        return 'En camino al punto de recogida';
      case 'llegue':
        return 'Has llegado al punto de recogida';
      case 'en_curso':
        return 'Viaje iniciado';
      case 'finalizado':
        return 'Viaje finalizado exitosamente';
      default:
        return 'Estado actualizado';
    }
  }

  /// Mostrar diálogo de calificación
  Future<void> _mostrarDialogoCalificacion() async {
    // Obtener ID del pasajero (usuario que solicita el servicio)
    final idUsuarioPasajero = servicio.idActivationCompanyUser;

    if (idUsuarioPasajero == 0) {
      print('⚠️ No se puede calificar: ID del pasajero no válido');
      return;
    }

    // Mostrar diálogo de calificación
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CalificacionDialog(
        idServicio: servicio.id,
        idUsuarioCalifica: widget.conductorId,
        idUsuarioCalificado: idUsuarioPasajero,
        tipoCalificacion: 'PASAJERO',
        nombreCalificado: pasajeroNombre ?? 'Pasajero',
        fotoCalificado: pasajeroFoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Confirmar antes de salir
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Salir del servicio?'),
            content: const Text(
              'No puedes salir mientras hay un servicio activo. '
              'Debes finalizar el viaje primero.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return confirmar ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Servicio en Curso'),
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          actions: [
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () {
                // TODO: Llamar al pasajero
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Mapa
            if (_miUbicacion != null && _destinoActual != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    _miUbicacion!.latitude,
                    _miUbicacion!.longitude,
                  ),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              )
            else
              const Center(child: CircularProgressIndicator()),

            // Panel de información y botones
            Positioned(left: 0, right: 0, bottom: 0, child: _buildPanelInfo()),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelInfo() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de estado
          _buildEstadoIndicator(),

          const SizedBox(height: 15),

          // Información del servicio
          _buildInfoServicio(),

          const SizedBox(height: 15),

          // Dirección actual
          _buildDireccionActual(),

          const SizedBox(height: 20),

          // Botón de acción según estado
          _buildBotonAccion(),
        ],
      ),
    );
  }

  Widget _buildEstadoIndicator() {
    final estados = {
      'aceptado': {'texto': 'YENDO AL PUNTO DE RECOGIDA', 'color': Colors.blue},
      'en_camino': {
        'texto': 'YENDO AL PUNTO DE RECOGIDA',
        'color': Colors.blue,
      },
      'llegue': {'texto': 'ESPERANDO PASAJERO', 'color': Colors.orange},
      'en_curso': {'texto': 'VIAJE EN CURSO', 'color': Colors.green},
    };

    final info = estados[_estadoActual] ?? {'texto': '', 'color': Colors.grey};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: info['color'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            info['texto'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoServicio() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.accent,
          backgroundImage: pasajeroFoto != null && pasajeroFoto!.isNotEmpty
              ? NetworkImage(pasajeroFoto!)
              : null,
          child: pasajeroFoto == null || pasajeroFoto!.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 30)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pasajeroNombre ?? 'Pasajero',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (pasajeroTelefono != null) ...[
                const SizedBox(height: 2),
                Text(
                  pasajeroTelefono!,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              // Nota: No se muestra precio porque funciona con taxímetro
            ],
          ),
        ),
        if (pasajeroTelefono != null)
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.green, size: 30),
            onPressed: () async {
              // Llamar al pasajero
              final Uri telUri = Uri(scheme: 'tel', path: pasajeroTelefono);
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se puede realizar la llamada'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildDireccionActual() {
    final direccion = _estadoActual == 'en_curso'
        ? servicio.destinoAddress
        : servicio.origenAddress;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            _estadoActual == 'en_curso'
                ? Icons.location_on
                : Icons.person_pin_circle,
            color: _estadoActual == 'en_curso' ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              direccion,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ubicacionTimer?.cancel();
    _trackingService.detenerSeguimiento();
    super.dispose();
  }

  Widget _buildBotonAccion() {
    String texto;
    String proximoEstado;
    Color color;

    switch (_estadoActual) {
      case 'aceptado':
      case 'en_camino':
        texto = 'LLEGUÉ AL PUNTO DE RECOGIDA';
        proximoEstado = 'llegue';
        color = Colors.blue;
        break;
      case 'llegue':
        texto = 'INICIAR VIAJE';
        proximoEstado = 'en_curso';
        color = Colors.green;
        break;
      case 'en_curso':
        texto = 'FINALIZAR VIAJE';
        proximoEstado = 'finalizado';
        color = Colors.orange;
        break;
      default:
        return const SizedBox();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _cambiarEstado(proximoEstado),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
