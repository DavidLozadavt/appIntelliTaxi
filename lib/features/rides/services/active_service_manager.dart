import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/config/pusher_config.dart';

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
      print('🔍 Consultando servicio activo...');

      final response = await _dio.get('taxi/servicio-activo');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true && data['data'] != null) {
          print('✅ Servicio activo encontrado');

          final servicioData = data['data']['servicio'];

          // Agregar conductor y vehículo al servicio
          if (data['data']['conductor'] != null) {
            servicioData['conductor'] = data['data']['conductor'];
          }
          if (data['data']['vehiculo'] != null) {
            servicioData['vehiculo'] = data['data']['vehiculo'];
          }

          final servicio = ServicioActivo.fromJson(servicioData);

          // Guardar el ID del servicio activo
          await saveActiveServiceId(servicio.id);
          _activeServiceId = servicio.id;

          print('📋 Servicio ID: ${servicio.id}');
          print('📊 Estado: ${servicio.estado.estado} (${servicio.idEstado})');

          return servicio;
        } else {
          print('ℹ️ No hay servicios activos');
          await clearActiveServiceId();
          return null;
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ No hay servicios activos (404)');
        await clearActiveServiceId();
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('ℹ️ No hay servicios activos');
        await clearActiveServiceId();
      } else {
        print('⚠️ Error obteniendo servicio activo: ${e.message}');
      }
    } catch (e) {
      print('⚠️ Error obteniendo servicio activo: $e');
    }
    return null;
  }

  /// Inicia el polling para actualizar el estado del servicio
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    stopPolling(); // Detener polling anterior si existe

    print('🔄 Iniciando polling cada ${interval.inSeconds}s');

    _pollingTimer = Timer.periodic(interval, (_) async {
      final servicio = await getActiveService();

      if (servicio != null) {
        // Notificar actualización
        onServiceUpdated?.call(servicio);

        // Si el servicio está finalizado o cancelado, detener polling
        if (!servicio.isActivo) {
          print('🏁 Servicio finalizado/cancelado, deteniendo polling');
          stopPolling();
          await clearActiveServiceId();
          onServiceCompleted?.call();
        }
      } else {
        // No hay servicio activo, detener polling
        print('⏹️ Sin servicio activo, deteniendo polling');
        stopPolling();
        onServiceCompleted?.call();
      }
    });
  }

  /// Detiene el polling
  void stopPolling() {
    if (_pollingTimer != null) {
      print('⏹️ Deteniendo polling');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  /// Suscribe a eventos de Pusher para el servicio activo
  Future<void> subscribeToServiceEvents(int servicioId) async {
    try {
      print('📡 Suscribiendo a eventos del servicio $servicioId');

      final channelName = 'servicio-$servicioId';

      // Suscribirse al canal
      await PusherService.subscribeSecondary(channelName);

      // Registrar handlers para diferentes eventos

      // Cuando cambia el estado del servicio
      PusherService.registerEventHandlerSecondary(
        '$channelName:estado-cambiado',
        (data) async {
          print('🔔 Estado del servicio cambió');
          final servicio = await getActiveService();
          if (servicio != null) {
            onServiceUpdated?.call(servicio);

            if (!servicio.isActivo) {
              await unsubscribeFromServiceEvents(servicioId);
              onServiceCompleted?.call();
            }
          }
        },
      );

      // Actualización de ubicación del conductor
      PusherService.registerEventHandlerSecondary(
        '$channelName:conductor-ubicacion',
        (data) {
          print('📍 Ubicación del conductor actualizada');
          // Aquí puedes actualizar el mapa con la nueva ubicación
        },
      );

      // Servicio aceptado por conductor
      PusherService.registerEventHandlerSecondary(
        '$channelName:servicio-aceptado',
        (data) async {
          print('✅ Servicio aceptado por conductor');
          final servicio = await getActiveService();
          if (servicio != null) {
            onServiceUpdated?.call(servicio);
          }
        },
      );

      print('✅ Suscripción exitosa a eventos del servicio');
    } catch (e) {
      print('⚠️ Error suscribiendo a eventos: $e');
    }
  }

  /// Desuscribe de eventos de Pusher
  Future<void> unsubscribeFromServiceEvents(int servicioId) async {
    try {
      print('🔕 Desuscribiendo de eventos del servicio $servicioId');

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

      print('✅ Desuscripción exitosa');
    } catch (e) {
      print('⚠️ Error desuscribiendo: $e');
    }
  }

  /// Guarda el ID del servicio activo en SharedPreferences
  Future<void> saveActiveServiceId(int servicioId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyActiveServiceId, servicioId);
      print('💾 Servicio ID guardado: $servicioId');
    } catch (e) {
      print('⚠️ Error guardando servicio ID: $e');
    }
  }

  /// Recupera el ID del servicio activo de SharedPreferences
  Future<int?> getActiveServiceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_keyActiveServiceId);
      if (id != null) {
        print('📂 Servicio ID recuperado: $id');
      }
      return id;
    } catch (e) {
      print('⚠️ Error recuperando servicio ID: $e');
      return null;
    }
  }

  /// Limpia el ID del servicio activo
  Future<void> clearActiveServiceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveServiceId);
      _activeServiceId = null;
      print('🗑️ Servicio ID limpiado');
    } catch (e) {
      print('⚠️ Error limpiando servicio ID: $e');
    }
  }

  /// Limpieza completa al cerrar
  Future<void> cleanup() async {
    print('🧹 Limpiando ActiveServiceManager');
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
