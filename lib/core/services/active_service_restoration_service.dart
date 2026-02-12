import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';

/// Servicio centralizado para verificar y restaurar servicios activos
/// Este servicio consulta el backend para obtener el servicio activo según el rol
class ActiveServiceRestorationService {
  final Dio _dio = DioClient.getInstance();

  /// Consulta si el usuario tiene un servicio activo como conductor
  /// Endpoint: GET /api/servicio-activo-conductor
  Future<Map<String, dynamic>?> verificarServicioActivoConductor() async {
    try {
      print('🔍 [Restoration] Verificando servicio activo del conductor...');

      final response = await _dio.get('taxi/servicio-activo-conductor');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true && data['data'] != null) {
          print('✅ [Restoration] Servicio activo conductor encontrado');

          final servicio = _normalizarServicio(data['data']['servicio']);
          final vehiculo = data['data']['vehiculo'];
          final pasajero = data['data']['pasajero'];

          return {
            'tipo': 'conductor',
            'servicio': servicio,
            'vehiculo': vehiculo,
            'pasajero': pasajero,
            'estado':
                servicio['idEstado'] ??
                (servicio['estado'] != null ? servicio['estado']['id'] : null),
          };
        }
      }

      print('ℹ️ [Restoration] No hay servicio activo del conductor');
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('ℹ️ [Restoration] No hay servicio activo del conductor (404)');
        return null;
      }
      print(
        '⚠️ [Restoration] Error verificando servicio conductor: ${e.message}',
      );
      return null;
    } catch (e) {
      print('⚠️ [Restoration] Error verificando servicio conductor: $e');
      return null;
    }
  }

  /// Consulta si el usuario tiene un servicio activo como pasajero
  /// Endpoint: GET /api/servicio-activo-pasajero
  Future<Map<String, dynamic>?> verificarServicioActivoPasajero() async {
    try {
      print('🔍 [Restoration] Verificando servicio activo del pasajero...');

      final response = await _dio.get('taxi/servicio-activo-pasajero');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true && data['data'] != null) {
          print('✅ [Restoration] Servicio activo pasajero encontrado');

          final servicio = _normalizarServicio(data['data']['servicio']);
          final conductor = data['data']['conductor'];
          final vehiculo = data['data']['vehiculo'];

          return {
            'tipo': 'pasajero',
            'servicio': servicio,
            'conductor': conductor,
            'vehiculo': vehiculo,
            'estado':
                servicio['idEstado'] ??
                (servicio['estado'] != null ? servicio['estado']['id'] : null),
          };
        }
      }

      print('ℹ️ [Restoration] No hay servicio activo del pasajero');
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('ℹ️ [Restoration] No hay servicio activo del pasajero (404)');
        return null;
      }
      print(
        '⚠️ [Restoration] Error verificando servicio pasajero: ${e.message}',
      );
      return null;
    } catch (e) {
      print('⚠️ [Restoration] Error verificando servicio pasajero: $e');
      return null;
    }
  }

  /// Verifica servicio activo según los roles del usuario
  /// Devuelve el servicio activo encontrado o null
  Future<Map<String, dynamic>?> verificarServicioActivoSegunRol(
    AuthProvider authProvider,
  ) async {
    if (authProvider.user == null) {
      print('⚠️ [Restoration] Usuario no autenticado');
      return null;
    }

    final roles = authProvider.roles;
    print('🔍 [Restoration] Roles del usuario: $roles');

    // Si es conductor, verificar servicio activo de conductor
    if (roles.contains('conductor') || roles.contains('CONDUCTOR')) {
      final servicioActivoConductor = await verificarServicioActivoConductor();
      if (servicioActivoConductor != null) {
        return servicioActivoConductor;
      }
    }

    // Si es pasajero, verificar servicio activo de pasajero
    if (roles.contains('pasajero') ||
        roles.contains('PASAJERO') ||
        roles.contains('passenger')) {
      final servicioActivoPasajero = await verificarServicioActivoPasajero();
      if (servicioActivoPasajero != null) {
        return servicioActivoPasajero;
      }
    }

    print('ℹ️ [Restoration] No hay servicios activos para este usuario');
    return null;
  }

  /// Normaliza los nombres de campos del backend a los que usa Flutter
  /// Backend usa: origenLat, destinoLat, etc.
  /// Flutter espera: origen_lat, destino_lat, etc.
  Map<String, dynamic> _normalizarServicio(Map<String, dynamic> servicio) {
    print('🔧 [Restoration] Normalizando campos del servicio...');
    print(
      '   origenLat: ${servicio['origenLat']}, origenLng: ${servicio['origenLng']}',
    );
    print(
      '   destinoLat: ${servicio['destinoLat']}, destinoLng: ${servicio['destinoLng']}',
    );

    return {
      ...servicio,
      // Normalizar coordenadas
      'origen_lat': servicio['origenLat'] ?? servicio['origen_lat'],
      'origen_lng': servicio['origenLng'] ?? servicio['origen_lng'],
      'destino_lat': servicio['destinoLat'] ?? servicio['destino_lat'],
      'destino_lng': servicio['destinoLng'] ?? servicio['destino_lng'],
      // Normalizar direcciones
      'origen_address':
          servicio['origenAddress'] ?? servicio['origen_address'] ?? 'Origen',
      'destino_address':
          servicio['destinoAddress'] ??
          servicio['destino_address'] ??
          'Destino',
      // Normalizar precios
      'precio_final':
          servicio['precioFinal'] ?? servicio['precio_final'] ?? '0.00',
      // Normalizar distancia y duración
      'distancia': servicio['distanciaTexto'] ?? servicio['distancia'],
      'duracion': servicio['duracionTexto'] ?? servicio['duracion'],
    };
  }

  /// Determina si un servicio está activo basándose en el idEstado
  /// Estados NO activos: cancelado, finalizado
  /// Estados activos: todos los demás con finServicio = null
  bool esServicioActivo(Map<String, dynamic> servicio) {
    final idEstado =
        servicio['idEstado'] ??
        (servicio['estado'] != null ? servicio['estado']['id'] : null);
    final finServicio = servicio['finServicio'];

    // Si finServicio no es null, el servicio ya terminó
    if (finServicio != null) {
      print('ℹ️ [Restoration] Servicio terminado (finServicio: $finServicio)');
      return false;
    }

    // Estados que indican que el servicio NO está activo
    // Ajustar según los IDs de estados en tu BD
    final estadosInactivos = [
      5,
      6,
      7,
    ]; // Ejemplo: 5=cancelado, 6=finalizado, 7=rechazado

    if (idEstado != null && estadosInactivos.contains(idEstado)) {
      print('ℹ️ [Restoration] Servicio con estado inactivo: $idEstado');
      return false;
    }

    return true;
  }
}
