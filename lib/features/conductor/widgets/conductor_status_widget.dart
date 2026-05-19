import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/services/conductor_location_service.dart';
import 'package:intellitaxi/features/conductor/services/turno_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Widget para controlar el estado del conductor (online/offline)
/// y el envío de ubicación en tiempo real
class ConductorStatusWidget extends StatefulWidget {
  final int idVehiculo;

  const ConductorStatusWidget({super.key, required this.idVehiculo});

  @override
  State<ConductorStatusWidget> createState() => _ConductorStatusWidgetState();
}

class _ConductorStatusWidgetState extends State<ConductorStatusWidget> {
  final ConductorService _conductorService = ConductorService();
  final ConductorLocationService _locationService = ConductorLocationService();
  final TurnoService _turnoService = TurnoService();

  bool _isOnline = false;
  bool _isLoading = false;
  Position? _lastPosition;
  String _statusMessage = 'Fuera de línea';
  int? _turnoActivo;
  String? _placaVehiculo;

  @override
  void initState() {
    super.initState();
    _cargarPlacaVehiculo();
    _checkPermissions();
  }

  Future<void> _cargarPlacaVehiculo() async {
    try {
      final vehiculos = await _conductorService.getVehiculosConductor();
      String? placa;
      for (final vehiculo in vehiculos) {
        if (vehiculo.id == widget.idVehiculo) {
          placa = vehiculo.placa;
          break;
        }
      }
      if (mounted && placa != null && placa.isNotEmpty) {
        setState(() {
          _placaVehiculo = placa;
        });
      }
    } catch (e) {
      AppLogger.d('⚠️ No se pudo cargar la placa del vehículo: $e');
    }
  }

  /// Verifica permisos de ubicación
  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('⚠️ Los servicios de ubicación están deshabilitados');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('❌ Permisos de ubicación denegados');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('❌ Permisos de ubicación denegados permanentemente');
      return;
    }
  }

  /// Alterna el estado online/offline
  void _toggleOnlineStatus() async {
    if (!mounted) return;

    // Verificar permisos primero
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnackBar('❌ Se necesitan permisos de ubicación');
      await _checkPermissions();
      return;
    }

    // Si va a conectarse
    if (!_isOnline) {
      await _iniciarTurnoYConexion();
    } else {
      await _detenerTurnoYConexion();
    }
  }

  /// Inicia turno y comienza envío de ubicación
  Future<void> _iniciarTurnoYConexion() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Obteniendo ubicación GPS...';
    });

    try {
      // 1. Obtener ubicación GPS primero
      AppLogger.d('📍 Obteniendo ubicación GPS antes de iniciar turno...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      AppLogger.d('✅ Ubicación GPS obtenida:');
      AppLogger.d('   Lat: ${position.latitude}');
      AppLogger.d('   Lng: ${position.longitude}');
      AppLogger.d('   Accuracy: ${position.accuracy}m');

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Iniciando turno...';
      });

      // 2. Preparar datos
      final lat = position.latitude;
      final lng = position.longitude;
      final vehiculoId = widget.idVehiculo;

      AppLogger.d('🔄 Llamando a iniciarTurno con:');
      AppLogger.d('   idVehiculo: $vehiculoId');
      AppLogger.d('   lat: $lat');
      AppLogger.d('   lng: $lng');

      // 3. Iniciar turno con la ubicación obtenida
      final turnoResponse = await _turnoService.iniciarTurno(
        idVehiculo: vehiculoId,
        lat: lat,
        lng: lng,
      );

      if (turnoResponse == null) {
        _showSnackBar('❌ No se pudo iniciar el turno');
        setState(() {
          _isLoading = false;
          _statusMessage = 'Fuera de línea';
        });
        return;
      }

      if (!turnoResponse.success) {
        final mensaje = turnoResponse.message ?? 'Error desconocido';
        _showSnackBar('❌ Error: $mensaje');
        setState(() {
          _isLoading = false;
          _statusMessage = 'Fuera de línea';
        });
        return;
      }

      _turnoActivo = turnoResponse.turno?.id;
      _showSnackBar('✅ Turno iniciado correctamente');

      // 2. Iniciar envío periódico de ubicación cada 10 segundos
      await _locationService.startSendingLocation(intervalSeconds: 10);

      setState(() {
        _isOnline = true;
        _isLoading = false;
        _statusMessage = _placaVehiculo?.isNotEmpty == true
            ? 'En linea con ${_placaVehiculo!}'
            : 'En linea - Turno #${_turnoActivo ?? ""}';
      });

      // 3. Actualizar posición en UI
      _updatePosition();
    } on PermissionDeniedException catch (e) {
      AppLogger.d('❌ Error de permisos: $e');
      _showSnackBar('❌ Permisos de ubicación denegados');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Fuera de línea';
      });
    } on LocationServiceDisabledException catch (e) {
      AppLogger.d('❌ Servicio de ubicación deshabilitado: $e');
      _showSnackBar('❌ Activa el GPS en tu dispositivo');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Fuera de línea';
      });
    } catch (e) {
      AppLogger.d('❌ Error iniciando turno: $e');
      AppLogger.d('   Tipo: ${e.runtimeType}');
      _showSnackBar('❌ Error al iniciar turno: ${e.toString()}');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Fuera de línea';
      });
    }
  }

  /// Detiene turno y envío de ubicación
  Future<void> _detenerTurnoYConexion() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Finalizando turno...';
    });

    try {
      // 1. Detener envío de ubicación (envía estado "desconectado")
      await _locationService.stopSendingLocation();

      // 2. Finalizar turno si existe
      if (_turnoActivo != null) {
        final success = await _turnoService.finalizarTurno(_turnoActivo!);

        if (success) {
          _showSnackBar('✅ Turno finalizado');
        } else {
          _showSnackBar('⚠️ Error al finalizar turno');
        }
      }

      setState(() {
        _isOnline = false;
        _isLoading = false;
        _statusMessage = 'Fuera de línea';
        _turnoActivo = null;
      });
    } catch (e) {
      AppLogger.d('Error finalizando turno: $e');
      _showSnackBar('❌ Error al finalizar turno');
      setState(() {
        _isOnline = false;
        _isLoading = false;
        _statusMessage = 'Fuera de línea';
      });
    }
  }

  /// Actualiza la posición mostrada
  Future<void> _updatePosition() async {
    if (!mounted) return;
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _lastPosition = position;
        });
      }
    } catch (e) {
      AppLogger.d('Error obteniendo posición: $e');
    }
  }

  /// Envía ubicación manualmente
  Future<void> _sendLocationNow() async {
    final success = await _locationService.sendLocationNow();
    if (success) {
      _showSnackBar('✅ Ubicación enviada');
      _updatePosition();
    } else {
      _showSnackBar('❌ Error enviando ubicación');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de estado
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading
                    ? Colors.orange
                    : (_isOnline ? Colors.green : Colors.grey),
                boxShadow: _isOnline
                    ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    )
                  : Icon(
                      _isOnline ? Iconsax.tick_circle_copy : Iconsax.login_copy,
                      size: 50,
                      color: Colors.white,
                    ),
            ),

            const SizedBox(height: 20),

            // Estado
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isOnline ? Colors.green : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // Información de ubicación
            if (_lastPosition != null) ...[
              const Divider(height: 30),
              _InfoRow(
                icon: Iconsax.location_copy,
                label: 'Latitud',
                value: _lastPosition!.latitude.toStringAsFixed(6),
              ),
              _InfoRow(
                icon: Iconsax.location_copy,
                label: 'Longitud',
                value: _lastPosition!.longitude.toStringAsFixed(6),
              ),
              _InfoRow(
                icon: Iconsax.speedometer_copy,
                label: 'Velocidad',
                value:
                    '${(_lastPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
              ),
            ],

            const SizedBox(height: 20),

            if (_isOnline && _placaVehiculo?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.car_copy,
                      size: 14,
                      color: _isOnline ? Colors.green : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _placaVehiculo!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isOnline ? Colors.green : Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botón principal
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _toggleOnlineStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnline ? Colors.red : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _isOnline
                      ? (_placaVehiculo?.isNotEmpty == true
                            ? '🔴 Finalizar turno • ${_placaVehiculo!}'
                            : '🔴 Finalizar Turno')
                      : '🟢 Iniciar Turno',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Botón de envío manual (solo cuando está online)
            if (_isOnline) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _sendLocationNow,
                icon: const Icon(Iconsax.send_2_copy),
                label: const Text('Enviar ubicación ahora'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}

/// Widget auxiliar para mostrar información
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
