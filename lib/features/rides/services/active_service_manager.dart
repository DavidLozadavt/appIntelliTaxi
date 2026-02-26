import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class ActiveServiceManager {
  final Dio _dio = DioClient.getInstance();
  Timer? _pollingTimer;
  int? _activeServiceId;
  Function(ServicioActivo)? onServiceUpdated;
  Function()? onServiceCompleted;

  static const String _keyActiveServiceId = 'active_service_id';

  /// Obtiene el servicio activo del usuario desde el backend
  Future<ServicioActivo?> getActiveService() async {
    try {
      AppLogger.d('🔍 Consultando servicio activo...');

      // Endpoints válidos actuales (el endpoint legacy /taxi/servicio-activo
      // ya no se usa y puede responder HTML del panel web).
      const endpoints = [
        'taxi/servicio-activo-pasajero',
        'taxi/servicio-activo-conductor',
      ];

      for (final endpoint in endpoints) {
        final servicio = await _getActiveServiceFromEndpoint(endpoint);
        if (servicio != null) {
          await saveActiveServiceId(servicio.id);
          _activeServiceId = servicio.id;

          AppLogger.d('✅ Servicio activo encontrado en $endpoint');
          AppLogger.d('📋 Servicio ID: ${servicio.id}');
          AppLogger.d(
            '📊 Estado: ${servicio.estado.estado} (${servicio.idEstado})',
          );
          return servicio;
        }
      }

      AppLogger.d('ℹ️ No hay servicios activos');
      await clearActiveServiceId();
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        AppLogger.d('ℹ️ No hay servicios activos');
        await clearActiveServiceId();
      } else {
        AppLogger.d('⚠️ Error obteniendo servicio activo: ${e.message}');
      }
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo servicio activo: $e');
    }
    return null;
  }

  Future<ServicioActivo?> _getActiveServiceFromEndpoint(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final dynamic raw = response.data;
      if (raw is! Map<String, dynamic>) {
        AppLogger.w(
          'Respuesta inválida en $endpoint (tipo: ${raw.runtimeType})',
        );
        return null;
      }

      final payload = raw['data'];
      if (raw['success'] != true || payload is! Map<String, dynamic>) {
        return null;
      }

      final servicioRaw = payload['servicio'];
      if (servicioRaw is! Map<String, dynamic>) {
        return null;
      }

      final servicioData = _normalizarServicio(
        Map<String, dynamic>.from(servicioRaw),
      );

      if (payload['conductor'] is Map<String, dynamic>) {
        servicioData['conductor'] = payload['conductor'];
      }
      if (payload['vehiculo'] is Map<String, dynamic>) {
        servicioData['vehiculo'] = payload['vehiculo'];
      }

      return ServicioActivo.fromJson(servicioData);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      AppLogger.w('Error consultando $endpoint: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.w('Error parseando $endpoint: $e');
      return null;
    }
  }

  Map<String, dynamic> _normalizarServicio(Map<String, dynamic> servicio) {
    return {
      ...servicio,
      'origen_lat': servicio['origenLat'] ?? servicio['origen_lat'],
      'origen_lng': servicio['origenLng'] ?? servicio['origen_lng'],
      'destino_lat': servicio['destinoLat'] ?? servicio['destino_lat'],
      'destino_lng': servicio['destinoLng'] ?? servicio['destino_lng'],
      'origen_address':
          servicio['origenAddress'] ?? servicio['origen_address'] ?? 'Origen',
      'destino_address':
          servicio['destinoAddress'] ??
          servicio['destino_address'] ??
          'Destino',
      'precio_final':
          servicio['precioFinal'] ?? servicio['precio_final'] ?? '0.00',
      'precio_estimado':
          servicio['precioEstimado'] ?? servicio['precio_estimado'] ?? '0.00',
      'distancia_texto':
          servicio['distanciaTexto'] ?? servicio['distancia_texto'],
      'duracion_texto': servicio['duracionTexto'] ?? servicio['duracion_texto'],
      'conductor_id': servicio['idConductor'] ?? servicio['conductor_id'],
      'tipo_servicio':
          servicio['tipoServicio'] ?? servicio['tipo_servicio'] ?? 'taxi',
    };
  }

  /// Inicia el polling para actualizar el estado del servicio
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    stopPolling(); // Detener polling anterior si existe

    AppLogger.d('🔄 Iniciando polling cada ${interval.inSeconds}s');

    _pollingTimer = Timer.periodic(interval, (_) async {
      try {
        final servicio = await getActiveService();

        if (servicio != null) {
          // Notificar actualización solo si el callback sigue definido
          if (onServiceUpdated != null) {
            onServiceUpdated?.call(servicio);
          }

          // Si el servicio está finalizado o cancelado, detener polling
          if (!servicio.isActivo) {
            AppLogger.d('🏁 Servicio finalizado/cancelado, deteniendo polling');
            stopPolling();
            await clearActiveServiceId();
            if (onServiceCompleted != null) {
              onServiceCompleted?.call();
            }
          }
        } else {
          // No hay servicio activo, detener polling
          AppLogger.d('⏹️ Sin servicio activo, deteniendo polling');
          stopPolling();
          if (onServiceCompleted != null) {
            onServiceCompleted?.call();
          }
        }
      } catch (e) {
        AppLogger.d('⚠️ Error en polling: $e');
      }
    });
  }

  /// Detiene el polling
  void stopPolling() {
    if (_pollingTimer != null) {
      AppLogger.d('⏹️ Deteniendo polling');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  /// Suscribe a eventos de Pusher para el servicio activo
  Future<void> subscribeToServiceEvents(int servicioId) async {
    try {
      AppLogger.d('📡 Suscribiendo a eventos del servicio $servicioId');

      final channelName = 'servicio-$servicioId';

      // Suscribirse al canal
      await PusherService.subscribeSecondary(channelName);

      // Registrar handlers para diferentes eventos

      // Cuando cambia el estado del servicio
      PusherService.registerEventHandlerSecondary(
        '$channelName:estado-cambiado',
        (data) async {
          AppLogger.d('🔔 Estado del servicio cambió');
          try {
            final servicio = await getActiveService();
            if (servicio != null && onServiceUpdated != null) {
              onServiceUpdated?.call(servicio);

              if (!servicio.isActivo) {
                await unsubscribeFromServiceEvents(servicioId);
                if (onServiceCompleted != null) {
                  onServiceCompleted?.call();
                }
              }
            }
          } catch (e) {
            AppLogger.d('⚠️ Error procesando estado-cambiado: $e');
          }
        },
      );

      // Actualización de ubicación del conductor
      PusherService.registerEventHandlerSecondary(
        '$channelName:conductor-ubicacion',
        (data) {
          AppLogger.d('📍 Ubicación del conductor actualizada');
          // Aquí puedes actualizar el mapa con la nueva ubicación
        },
      );

      // Servicio aceptado por conductor
      PusherService.registerEventHandlerSecondary(
        '$channelName:servicio-aceptado',
        (data) async {
          AppLogger.d('✅ Servicio aceptado por conductor');
          try {
            final servicio = await getActiveService();
            if (servicio != null && onServiceUpdated != null) {
              onServiceUpdated?.call(servicio);
            }
          } catch (e) {
            AppLogger.d('⚠️ Error procesando servicio-aceptado: $e');
          }
        },
      );

      AppLogger.d('✅ Suscripción exitosa a eventos del servicio');
    } catch (e) {
      AppLogger.d('⚠️ Error suscribiendo a eventos: $e');
    }
  }

  /// Desuscribe de eventos de Pusher
  Future<void> unsubscribeFromServiceEvents(int servicioId) async {
    try {
      AppLogger.d('🔕 Desuscribiendo de eventos del servicio $servicioId');

      final channelName = 'servicio-$servicioId';

      // Desuscribirse del canal
      await PusherService.unsubscribeSecondary(channelName);

      // Eliminar handlers
      PusherService.unregisterEventHandlerSecondary(
        '$channelName:estado-cambiado',
      );
      PusherService.unregisterEventHandlerSecondary(
        '$channelName:conductor-ubicacion',
      );
      PusherService.unregisterEventHandlerSecondary(
        '$channelName:servicio-aceptado',
      );

      AppLogger.d('✅ Desuscripción exitosa');
    } catch (e) {
      AppLogger.d('⚠️ Error desuscribiendo: $e');
    }
  }

  /// Guarda el ID del servicio activo en SharedPreferences
  Future<void> saveActiveServiceId(int servicioId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyActiveServiceId, servicioId);
      AppLogger.d('💾 Servicio ID guardado: $servicioId');
    } catch (e) {
      AppLogger.d('⚠️ Error guardando servicio ID: $e');
    }
  }

  /// Recupera el ID del servicio activo de SharedPreferences
  Future<int?> getActiveServiceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_keyActiveServiceId);
      if (id != null) {
        AppLogger.d('📂 Servicio ID recuperado: $id');
      }
      return id;
    } catch (e) {
      AppLogger.d('⚠️ Error recuperando servicio ID: $e');
      return null;
    }
  }

  /// Limpia el ID del servicio activo
  Future<void> clearActiveServiceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveServiceId);
      _activeServiceId = null;
      AppLogger.d('🗑️ Servicio ID limpiado');
    } catch (e) {
      AppLogger.d('⚠️ Error limpiando servicio ID: $e');
    }
  }

  /// Limpieza completa al cerrar
  Future<void> cleanup() async {
    AppLogger.d('🧹 Limpiando ActiveServiceManager');
    stopPolling();

    if (_activeServiceId != null) {
      await unsubscribeFromServiceEvents(_activeServiceId!);
    }

    await clearActiveServiceId();
    onServiceUpdated = null;
    onServiceCompleted = null;
  }

  /// Verifica si hay un servicio activo guardado localmente
  Future<bool> hasLocalActiveService() async {
    final id = await getActiveServiceId();
    return id != null;
  }
}
