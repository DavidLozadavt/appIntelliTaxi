import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/features/rides/presentation/pasajero_esperando_conductor_screen.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';

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
      print('⚠️ [Navigation] ID del conductor no disponible');
      return;
    }

    print('📱 [Navigation] Navegando a pantalla de conductor...');
    print('📊 [Navigation] Estado del servicio: ${servicio['idEstado']}');

    // Construir el objeto completo del servicio con datos necesarios
    final servicioCompleto = <String, dynamic>{
      'id': servicio['id'],
      'idEstado': servicio['idEstado'],
      'origen_lat': servicio['origen_lat'],
      'origen_lng': servicio['origen_lng'],
      'destino_lat': servicio['destino_lat'],
      'destino_lng': servicio['destino_lng'],
      'origen_address': servicio['origen_address'],
      'destino_address': servicio['destino_address'],
      'precio_final': servicio['precio_final'],
      'distancia': servicio['distancia'],
      'duracion': servicio['duracion'],
      'usuario_pasajero': pasajero != null
          ? {
              'id': pasajero['id'],
              'persona': {
                'nombre1': pasajero['nombre']?.split(' ').first ?? '',
                'apellido1':
                    pasajero['nombre']?.split(' ').skip(1).join(' ') ?? '',
                'celular': pasajero['telefono'],
                'foto': pasajero['foto'],
              },
            }
          : null,
      'vehiculo': vehiculo,
      'estado': servicio['estado'],
      ...?servicio, // Incluir cualquier otro dato del servicio
    };

    print('📍 [Navigation] Coordenadas normalizadas:');
    print(
      '   Origen: ${servicioCompleto['origen_lat']}, ${servicioCompleto['origen_lng']}',
    );
    print(
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

    print('✅ [Navigation] Navegación a conductor completada');
  }

  /// Navega a la pantalla de servicio activo del pasajero
  static Future<void> _navigateToPasajeroService(
    BuildContext context,
    Map<String, dynamic> servicioData,
  ) async {
    final servicio = servicioData['servicio'];
    final conductor = servicioData['conductor'];
    final vehiculo = servicioData['vehiculo'];

    print('📱 [Navigation] Navegando a pantalla de pasajero...');
    print('📊 [Navigation] Estado del servicio: ${servicio['idEstado']}');

    // Construir el objeto completo del servicio
    final servicioCompleto = <String, dynamic>{
      'id': servicio['id'],
      'idEstado': servicio['idEstado'],
      'origen_lat': servicio['origen_lat'],
      'origen_lng': servicio['origen_lng'],
      'destino_lat': servicio['destino_lat'],
      'destino_lng': servicio['destino_lng'],
      'origen_address': servicio['origen_address'],
      'destino_address': servicio['destino_address'],
      'precio_final': servicio['precio_final'],
      'distancia': servicio['distancia'],
      'duracion': servicio['duracion'],
      'conductor': conductor,
      'vehiculo': vehiculo,
      'conductor_id': conductor?['id'],
      'estado': servicio['estado'],
      ...?servicio, // Incluir cualquier otro dato del servicio
    };

    print('📍 [Navigation] Coordenadas normalizadas:');
    print(
      '   Origen: ${servicioCompleto['origen_lat']}, ${servicioCompleto['origen_lng']}',
    );
    print(
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

    print('✅ [Navigation] Navegación a pasajero completada');
  }

  /// Determina si debe mostrar la pantalla de servicio activo
  /// basándose en el estado del servicio
  static bool shouldShowActiveService(Map<String, dynamic> servicioData) {
    final servicio = servicioData['servicio'];
    final idEstado = servicio['idEstado'];
    final finServicio = servicio['finServicio'];

    // Si el servicio ya finalizó, no mostrar
    if (finServicio != null) {
      print('ℹ️ [Navigation] Servicio ya finalizado');
      return false;
    }

    // Estados que NO deben mostrar pantalla activa
    // Ajustar según tus estados en BD
    final estadosInactivos = [5, 6, 7]; // cancelado, finalizado, rechazado

    if (idEstado != null && estadosInactivos.contains(idEstado)) {
      print('ℹ️ [Navigation] Estado inactivo: $idEstado');
      return false;
    }

    return true;
  }
}
