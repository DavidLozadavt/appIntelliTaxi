import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/services/active_service_check_cache.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/taxi/data/taxi_servicio_estado.dart';

/// Servicio centralizado para verificar y restaurar servicios activos
/// Este servicio consulta el backend para obtener el servicio activo según el rol
class ActiveServiceRestorationService {
  final Dio _dio = DioClient.getInstance();

  /// Bootstrap ligero: `GET /taxi/conductor/estado-actual`
  Future<TaxiConductorEstadoActual?> obtenerEstadoActualConductor() async {
    try {
      final response = await _dio.get('taxi/conductor/estado-actual');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return TaxiConductorEstadoActual.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return null;
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ [Restoration] estado-actual conductor: ${e.message}',
      );
      return null;
    }
  }

  /// Consulta si el usuario tiene un servicio activo como conductor
  /// Endpoint: GET /api/servicio-activo-conductor
  Future<Map<String, dynamic>?> verificarServicioActivoConductor() async {
    try {
      AppLogger.d(
        '🔍 [Restoration] Verificando servicio activo del conductor...',
      );

      final response = await _dio.get('taxi/servicio-activo-conductor');
      if (response.statusCode == 404) {
        AppLogger.d(
          'ℹ️ [Restoration] No hay servicio activo del conductor (404)',
        );
        return null;
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true && data['data'] != null) {
          AppLogger.d('✅ [Restoration] Servicio activo conductor encontrado');

          final servicio = _normalizarServicio(data['data']['servicio']);
          final vehiculo = data['data']['vehiculo'];
          final pasajero = data['data']['pasajero'];

          return {
            'tipo': 'conductor',
            'en_servicio': data['en_servicio'] ?? true,
            'servicio': servicio,
            'vehiculo': vehiculo,
            'pasajero': pasajero,
            'estado':
                servicio['idEstado'] ??
                (servicio['estado'] != null ? servicio['estado']['id'] : null),
          };
        }
      }

      AppLogger.d('ℹ️ [Restoration] No hay servicio activo del conductor');
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        AppLogger.d(
          'ℹ️ [Restoration] No hay servicio activo del conductor (404)',
        );
        return null;
      }
      AppLogger.d(
        '⚠️ [Restoration] Error verificando servicio conductor: ${e.message}',
      );
      return null;
    } catch (e) {
      AppLogger.d('⚠️ [Restoration] Error verificando servicio conductor: $e');
      return null;
    }
  }

  /// Consulta si el usuario tiene un servicio activo como pasajero
  /// Endpoint: GET /api/servicio-activo-pasajero
  Future<Map<String, dynamic>?> verificarServicioActivoPasajero({
    bool quiet = false,
  }) async {
    try {
      if (!quiet) {
        AppLogger.d(
          '🔍 [Restoration] Verificando servicio activo del pasajero...',
        );
      }

      final response = await _dio.get('taxi/servicio-activo-pasajero');
      if (response.statusCode == 404) {
        if (!quiet) {
          AppLogger.d(
            'ℹ️ [Restoration] No hay servicio activo del pasajero (404)',
          );
        }
        return null;
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true && data['data'] != null) {
          AppLogger.d('✅ [Restoration] Servicio activo pasajero encontrado');

          final servicio = _normalizarServicio(data['data']['servicio']);
          final conductor = data['data']['conductor'];
          final vehiculo = data['data']['vehiculo'];

          return {
            'tipo': 'pasajero',
            'en_servicio': data['en_servicio'] ?? true,
            'servicio': servicio,
            'conductor': conductor,
            'vehiculo': vehiculo,
            'estado':
                servicio['idEstado'] ??
                (servicio['estado'] != null ? servicio['estado']['id'] : null),
          };
        }
      }

      AppLogger.d('ℹ️ [Restoration] No hay servicio activo del pasajero');
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        AppLogger.d(
          'ℹ️ [Restoration] No hay servicio activo del pasajero (404)',
        );
        return null;
      }
      AppLogger.d(
        '⚠️ [Restoration] Error verificando servicio pasajero: ${e.message}',
      );
      return null;
    } catch (e) {
      AppLogger.d('⚠️ [Restoration] Error verificando servicio pasajero: $e');
      return null;
    }
  }

  /// Verifica servicio activo según los roles del usuario
  /// Devuelve el servicio activo encontrado o null
  Future<Map<String, dynamic>?> verificarServicioActivoSegunRol(
    AuthProvider authProvider,
  ) async {
    final user = authProvider.user;
    if (user == null) {
      AppLogger.d('⚠️ [Restoration] Usuario no autenticado');
      return null;
    }

    return ActiveServiceCheckCache.dedupe(
      '${user.id}_${authProvider.activeRole ?? authProvider.roles.join(",")}',
      () async {
        AppLogger.d('🔍 [Restoration] Roles del usuario: ${authProvider.roles}');

        if (authProvider.hasConductorRole) {
          final servicioActivoConductor =
              await verificarServicioActivoConductor();
          if (servicioActivoConductor != null) {
            return servicioActivoConductor;
          }
        }

        if (authProvider.hasPasajeroRole) {
          final servicioActivoPasajero =
              await verificarServicioActivoPasajero(quiet: true);
          if (servicioActivoPasajero != null) {
            return servicioActivoPasajero;
          }
        }

        AppLogger.d(
          'ℹ️ [Restoration] No hay servicios activos para este usuario',
        );
        return null;
      },
    );
  }

  /// Normaliza los nombres de campos del backend a los que usa Flutter
  /// Backend usa: origenLat, destinoLat, etc.
  /// Flutter espera: origen_lat, destino_lat, etc.
  Map<String, dynamic> _normalizarServicio(Map<String, dynamic> servicio) {
    AppLogger.d('🔧 [Restoration] Normalizando campos del servicio...');
    AppLogger.d(
      '   origenLat: ${servicio['origenLat']}, origenLng: ${servicio['origenLng']}',
    );
    AppLogger.d(
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

  /// Respuesta 200 con datos o `null` si el backend responde 404 (sin servicio activo).
  /// Propaga [DioException] en fallos de red para no confundir con “servicio cerrado”.
  Future<Map<String, dynamic>?> obtenerServicioActivoConductorOCerrado() async {
    try {
      final response = await _dio.get('taxi/servicio-activo-conductor');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map &&
            data['success'] == true &&
            data['data'] is Map) {
          final inner = Map<String, dynamic>.from(data['data'] as Map);
          final rawServicio = inner['servicio'];
          if (rawServicio is Map) {
            final servicio = _normalizarServicio(
              Map<String, dynamic>.from(rawServicio),
            );
            return {
              'tipo': 'conductor',
              'servicio': servicio,
              'vehiculo': inner['vehiculo'],
              'pasajero': inner['pasajero'],
            };
          }
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        AppLogger.d(
          'ℹ️ [Restoration] servicio-activo-conductor 404 (sin servicio)',
        );
        return null;
      }
      rethrow;
    }
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
      AppLogger.d(
        'ℹ️ [Restoration] Servicio terminado (finServicio: $finServicio)',
      );
      return false;
    }

    // Estados inactivos taxi móvil: 6 cancelado, 22 finalizado (doc Mayo 2026)
    final estadosInactivos = [6, 22];

    if (idEstado != null && estadosInactivos.contains(idEstado)) {
      AppLogger.d('ℹ️ [Restoration] Servicio con estado inactivo: $idEstado');
      return false;
    }

    return true;
  }
}
