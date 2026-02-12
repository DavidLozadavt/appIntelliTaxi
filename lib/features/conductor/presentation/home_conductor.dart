import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/conductor/widgets/vehiculo_selection_sheet.dart';
import 'package:intellitaxi/features/conductor/widgets/documentos_alert_dialog.dart';
import 'package:intellitaxi/features/conductor/widgets/solicitud_servicio_card.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

class HomeConductor extends StatefulWidget {
  final List<dynamic> stories;

  const HomeConductor({super.key, required this.stories});

  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor> {
  GoogleMapController? _mapController;
  Brightness? _lastBrightness;
  late ConductorHomeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ConductorHomeProvider();
    _provider.initialize();
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
    _provider.dispose();
    super.dispose();
  }

  /// Acepta la solicitud de servicio
  void _aceptarSolicitud(String solicitudId) async {
    final solicitud = _provider.solicitudesActivas.firstWhere(
      (s) => s['solicitud_id']?.toString() == solicitudId,
      orElse: () => {},
    );

    if (solicitud.isEmpty) {
      print('⚠️ Solicitud no encontrada: $solicitudId');
      return;
    }

    print('👉 Intentando aceptar solicitud ID: $solicitudId');

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

    // Nota: No se calcula precio porque funciona con taxímetro

    // Controladores para el diálogo
    final mensajeController = TextEditingController(text: 'Voy en camino');

    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // gradient: LinearGradient(
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            //   colors: [Colors.white, AppColors.accent.withOpacity(0.05)],
            // ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono principal
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Iconsax.car_copy,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  const Text(
                    'Aceptar Solicitud',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confirma que aceptarás este servicio',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Información del pasajero
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        // Avatar del pasajero
                        solicitud['pasajero_foto'] != null &&
                                solicitud['pasajero_foto'].toString().isNotEmpty
                            ? CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                  solicitud['pasajero_foto'],
                                ),
                                backgroundColor: Colors.grey.shade300,
                                onBackgroundImageError: (_, __) {},
                              )
                            : CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.accent.withOpacity(
                                  0.15,
                                ),
                                child: Icon(
                                  Iconsax.user_copy,
                                  color: AppColors.accent,
                                  size: 24,
                                ),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pasajero',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                solicitud['pasajero_nombre'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Origen y destino
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Origen
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Iconsax.record_circle_copy,
                                color: AppColors.accent,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Origen',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    solicitud['origen'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Destino
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                // color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Iconsax.location_copy,
                                color: Colors.red.shade700,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Destino',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    solicitud['destino'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 20),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: AppColors.accent.withOpacity(0.3),
                          ),
                          child: const Text(
                            'Aceptar Servicio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        ),
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
      // Llamar al provider para aceptar
      final response = await _provider.aceptarSolicitud(
        solicitudId,
        _provider.vehiculoSeleccionado?.id ?? 0,
      );

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      if (response == null) {
        throw Exception('No se pudo aceptar la solicitud');
      }

      // Mostrar éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Servicio aceptado: ${solicitud['pasajero_nombre'] ?? 'Pasajero'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ Solicitud $solicitudId aceptada exitosamente');

      // Navegar a la pantalla de servicio activo del conductor
      if (mounted && response['servicio'] != null) {
        try {
          // Obtener conductor ID del auth provider
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final conductorId = authProvider.user?.id ?? 0;

          // Navegar a ConductorServicioActivoScreen pasando el objeto servicio
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConductorServicioActivoScreen(
                servicio: response['servicio'],
                conductorId: conductorId,
              ),
            ),
          );
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

    _provider.rechazarSolicitud(solicitudId);
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

  /// Verifica documentos del conductor y muestra alertas
  Future<void> _verificarDocumentos() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId == null) return;

    final resultado = await _provider.verificarDocumentos(userId);
    final vencidos = resultado['vencidos'] ?? [];
    final porVencer = resultado['porVencer'] ?? [];

    if ((vencidos.isNotEmpty || porVencer.isNotEmpty) && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DocumentosAlertDialog(
          documentosVencidos: vencidos,
          documentosPorVencer: porVencer,
        ),
      );
    }
  }

  /// Muestra el selector de vehículo
  Future<void> _mostrarSelectorVehiculo() async {
    if (!mounted) return;

    // Guardar referencia al messenger antes de operaciones asíncronas
    final messenger = ScaffoldMessenger.of(context);

    if (_provider.vehiculosDisponibles.isEmpty) {
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
        vehiculos: _provider.vehiculosDisponibles,
        onVehiculoSelected: (vehiculo) async {
          // Seleccionar vehículo e iniciar turno
          _provider.seleccionarVehiculo(vehiculo);
          final turnoIniciado = await _provider.iniciarTurno(vehiculo.id);

          if (turnoIniciado && mounted) {
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
    if (!_provider.isOnline) {
      // Activándose: debe seleccionar vehículo primero
      if (_provider.vehiculoSeleccionado == null) {
        await _mostrarSelectorVehiculo();
      } else {
        await _provider.toggleOnlineStatus();
      }
    } else {
      // Desactivándose: finalizar turno
      final success = await _provider.finalizarTurno();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno finalizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<ConductorHomeProvider>(
        builder: (context, provider, child) => Stack(
          children: [
            // Mapa de Google Maps
            provider.currentPosition == null
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
                                colors: provider.isLoadingLocation
                                    ? [
                                        AppColors.accent.withOpacity(0.2),
                                        AppColors.accent.withOpacity(0.05),
                                      ]
                                    : [
                                        Colors.grey.withOpacity(0.2),
                                        Colors.grey.withOpacity(0.05),
                                      ],
                              ),
                              boxShadow: provider.isLoadingLocation
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(
                                          0.2,
                                        ),
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
                                  color: provider.isLoadingLocation
                                      ? AppColors.accent.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15),
                                ),
                                child: Center(
                                  child: provider.isLoadingLocation
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
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(AppColors.accent),
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
                            provider.isLoadingLocation
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
                              provider.locationMessage,
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
                          if (!provider.isLoadingLocation) ...[
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
                                onPressed: () => provider.initializeLocation(),
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
                : StandardMap(
                    initialPosition: LatLng(
                      provider.currentPosition!.latitude,
                      provider.currentPosition!.longitude,
                    ),
                    zoom: 15,
                    markers: {
                      Marker(
                        markerId: const MarkerId('current_location'),
                        position: LatLng(
                          provider.currentPosition!.latitude,
                          provider.currentPosition!.longitude,
                        ),
                        infoWindow: const InfoWindow(
                          title: 'Tu ubicación',
                          snippet: 'Estás aquí',
                        ),
                      ),
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),

            // Botón de estado del conductor (inferior centro)
            if (provider.currentPosition != null)
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
                          colors: provider.isOnline
                              ? [AppColors.accent, Colors.orangeAccent]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: provider.isOnline
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
                            provider.isOnline
                                ? Icons.check_circle
                                : Icons.cancel,
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
                                  provider.isOnline
                                      ? 'En Línea'
                                      : 'Desconectado',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (provider.vehiculoSeleccionado != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    provider.vehiculoSeleccionado!.placa,
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
            if (provider.currentPosition != null)
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () => provider.initializeLocation(),
                  backgroundColor: Colors.white,
                  elevation: 4,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ),

            // Tarjetas flotantes de solicitudes de servicio (scrolleable)
            if (provider.solicitudesActivas.isNotEmpty)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                bottom: 100,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.solicitudesActivas.length,
                  itemBuilder: (context, index) {
                    final solicitud = provider.solicitudesActivas[index];
                    final solicitudId =
                        solicitud['solicitud_id']?.toString() ?? '';

                    // Validar que el ID existe
                    if (solicitudId.isEmpty) {
                      print('⚠️ Solicitud sin ID válido en índice $index');
                      return const SizedBox.shrink();
                    }

                    return Dismissible(
                      key: Key(solicitudId),
                      direction: DismissDirection.horizontal,
                      onDismissed: (direction) {
                        provider.rechazarSolicitud(solicitudId);
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
          ],
        ),
      ),
    );
  }
}
