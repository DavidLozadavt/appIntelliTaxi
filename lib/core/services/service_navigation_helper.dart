import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/features/pasajero/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';

/// Servicio de navegación para restaurar pantallas de servicio activo
/// Maneja la lógica de navegación según el estado del servicio y el rol
class ServiceNavigationHelper {
  /// Navega a la pantalla correcta según el servicio activo
  static Future<void> navigateToActiveService(
    BuildContext context,
    Map<String, dynamic> servicioData,
    AuthProvider authProvider,
  ) async {
    final tipo = servicioData['tipo'];
    final servicio = servicioData['servicio'];
    final servicioIdRaw = servicio?['id'];
    final servicioId = servicioIdRaw is int
        ? servicioIdRaw
        : int.tryParse(servicioIdRaw?.toString() ?? '');

    if (tipo is String && servicioId != null) {
      if (ActiveServiceScreenRegistry.isShowing(
        type: tipo,
        serviceId: servicioId,
      )) {
        AppLogger.d(
          'ℹ️ [Navigation] La pantalla activa ya está visible. Se omite navegación.',
        );
        return;
      }
    }

    if (tipo == 'conductor') {
      await _navigateToConductorService(context, servicioData, authProvider);
    } else if (tipo == 'pasajero') {
      await _navigateToPasajeroService(context, servicioData);
    }
  }

  /// Navega a la pantalla de servicio activo del conductor
  static Future<void> _navigateToConductorService(
    BuildContext context,
    Map<String, dynamic> servicioData,
    AuthProvider authProvider,
  ) async {
    final servicio = servicioData['servicio'];
    final vehiculo = servicioData['vehiculo'];
    final pasajero = servicioData['pasajero'];
    final conductorId = authProvider.user?.id;

    if (conductorId == null) {
      AppLogger.d('⚠️ [Navigation] ID del conductor no disponible');
      return;
    }

    AppLogger.d('📱 [Navigation] Navegando a pantalla de conductor...');
    AppLogger.d('📊 [Navigation] Estado del servicio: ${servicio['idEstado']}');

    final servicioCompleto = ServicioPayloadAdapter.normalize(
      servicio: Map<String, dynamic>.from(servicio),
      pasajero: pasajero != null ? Map<String, dynamic>.from(pasajero) : null,
      vehiculo: vehiculo != null ? Map<String, dynamic>.from(vehiculo) : null,
    );

    AppLogger.d('📍 [Navigation] Coordenadas normalizadas:');
    AppLogger.d(
      '   Origen: ${servicioCompleto['origen_lat']}, ${servicioCompleto['origen_lng']}',
    );
    AppLogger.d(
      '   Destino: ${servicioCompleto['destino_lat']}, ${servicioCompleto['destino_lng']}',
    );

    // Navegar a la pantalla del conductor
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ConductorServicioActivoScreen(
          servicio: servicioCompleto,
          conductorId: conductorId,
        ),
      ),
    );

    AppLogger.d('✅ [Navigation] Navegación a conductor completada');
  }

  /// Navega a la pantalla de servicio activo del pasajero
  static Future<void> _navigateToPasajeroService(
    BuildContext context,
    Map<String, dynamic> servicioData,
  ) async {
    final servicio = servicioData['servicio'];
    final conductor = servicioData['conductor'];
    final vehiculo = servicioData['vehiculo'];

    AppLogger.d('📱 [Navigation] Navegando a pantalla de pasajero...');
    AppLogger.d('📊 [Navigation] Estado del servicio: ${servicio['idEstado']}');

    final servicioCompleto = ServicioPayloadAdapter.normalize(
      servicio: Map<String, dynamic>.from(servicio),
      conductor: conductor != null
          ? Map<String, dynamic>.from(conductor)
          : null,
      vehiculo: vehiculo != null ? Map<String, dynamic>.from(vehiculo) : null,
    )..['conductor_id'] = conductor?['id'];

    AppLogger.d('📍 [Navigation] Coordenadas normalizadas:');
    AppLogger.d(
      '   Origen: ${servicioCompleto['origen_lat']}, ${servicioCompleto['origen_lng']}',
    );
    AppLogger.d(
      '   Destino: ${servicioCompleto['destino_lat']}, ${servicioCompleto['destino_lng']}',
    );

    // Navegar a la pantalla del pasajero
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PasajeroEsperandoConductorScreen(
          servicioId: servicio['id'],
          datosServicio: servicioCompleto,
        ),
      ),
    );

    AppLogger.d('✅ [Navigation] Navegación a pasajero completada');
  }

  /// Determina si debe mostrar la pantalla de servicio activo
  /// basándose en el estado del servicio
  static bool shouldShowActiveService(Map<String, dynamic> servicioData) {
    final tipo = servicioData['tipo']?.toString().toLowerCase();
    final servicio = servicioData['servicio'];
    final idEstado = servicio['idEstado'];
    final estadoNombre =
        (servicio['estado'] is Map ? servicio['estado']['estado'] : null)
            ?.toString()
            .toUpperCase();
    final tipoServicio = servicio['tipoServicio']?.toString().toUpperCase();
    final finServicio = servicio['finServicio'];

    // Si el servicio ya finalizó, no mostrar
    if (finServicio != null) {
      AppLogger.d('ℹ️ [Navigation] Servicio ya finalizado');
      return false;
    }

    // Estados que NO deben mostrar pantalla activa (doc Mayo 2026)
    final estadosInactivos = [6, 22]; // cancelado, finalizado

    if (idEstado != null && estadosInactivos.contains(idEstado)) {
      AppLogger.d('ℹ️ [Navigation] Estado inactivo: $idEstado');
      return false;
    }

    // Conductor: para ofertas directas/sin aceptar, NO abrir pantalla activa automáticamente.
    // Debe quedarse en Home para aceptar o rechazar la solicitud.
    final isConductor = tipo == 'conductor';
    final isPendiente =
        idEstado == 4 ||
        estadoNombre == 'PENDIENTE' ||
        estadoNombre == 'PENDING';
    if (isConductor && isPendiente) {
      AppLogger.d(
        'ℹ️ [Navigation] Conductor con solicitud pendiente'
        ' (tipoServicio=$tipoServicio, estado=$estadoNombre), no navegar a activo',
      );
      return false;
    }

    return true;
  }
}
