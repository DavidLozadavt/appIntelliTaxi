import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/main.dart';

/// Navegación a pantalla de servicio activo tras aceptar (mapa / exclusiva / fullscreen).
abstract final class ConductorServicioNavegacion {
  static Future<void> abrirTrasAceptar(
    BuildContext context, {
    required ConductorHomeProvider home,
    required int conductorId,
    Map<String, dynamic>? acceptResponse,
    bool reemplazar = false,
  }) async {
    final aceptacionOk = acceptResponse != null &&
        ServicioPayloadAdapter.esAceptacionExitosa(acceptResponse);

    Map<String, dynamic>? nav;
    if (acceptResponse != null) {
      nav = ServicioPayloadAdapter.unwrapNavegacionPayload(acceptResponse);
    }
    nav ??= home.servicioActivoPendienteNavegacion;

    final servicioId = acceptResponse != null
        ? ServicioPayloadAdapter.servicioIdDesdeAceptacion(acceptResponse)
        : null;

    final sidRespaldo = home.servicioActivoId ?? servicioId;

    if (nav == null &&
        (home.enServicio || aceptacionOk) &&
        sidRespaldo != null) {
      try {
        nav = await ConductorService().getServicioActivoConductor();
      } catch (e) {
        AppLogger.d('⚠️ No se pudo cargar servicio activo tras aceptar: $e');
      }
    }

    if (nav == null && (home.enServicio || aceptacionOk)) {
      nav = await _navDesdePersistenciaLocal(servicioId: sidRespaldo);
    }

    if (nav == null && (home.enServicio || aceptacionOk) && sidRespaldo != null) {
      AppLogger.d(
        '⚠️ API/local incompletos; abriendo servicio #$sidRespaldo con payload mínimo',
      );
      nav = {
        'servicio': {
          'id': sidRespaldo,
          'servicio_id': sidRespaldo,
        },
      };
    }

    if (nav == null) {
      AppLogger.d('⚠️ Aceptación sin payload de navegación');
      return;
    }

    home.clearServicioActivoPendienteNavegacion();

    Map<String, dynamic>? normalizado;
    if (acceptResponse != null) {
      normalizado =
          ServicioPayloadAdapter.servicioNormalizadoDesdeAceptacion(
            acceptResponse,
          );
    }
    normalizado ??= _normalizarDesdeNav(nav);
    if (normalizado == null) {
      AppLogger.d('⚠️ No se pudo normalizar servicio para navegación');
      return;
    }

    final navCtx = context.mounted ? context : navigatorKey.currentContext;
    if (navCtx == null || !navCtx.mounted) {
      AppLogger.d('⚠️ Sin contexto para abrir servicio activo');
      return;
    }

    AppLogger.d(
      '🚀 Navegando a servicio activo #${normalizado['id'] ?? normalizado['servicio_id']}',
    );

    final route = MaterialPageRoute<void>(
      builder: (_) => ConductorServicioActivoScreen(
        servicio: normalizado!,
        conductorId: conductorId,
      ),
    );

    if (reemplazar) {
      await Navigator.of(navCtx).pushReplacement(route);
    } else {
      await Navigator.of(navCtx).push(route);
    }
  }

  static Future<Map<String, dynamic>?> _navDesdePersistenciaLocal({
    int? servicioId,
  }) async {
    try {
      final local = await ServicioPersistenciaService().obtenerServicioActivo();
      if (local == null || local['tipo']?.toString() != 'conductor') {
        return null;
      }
      final localId = local['servicioId'];
      if (servicioId != null &&
          localId != null &&
          localId.toString() != servicioId.toString()) {
        AppLogger.d(
          '⚠️ Persistencia local es otro servicio ($localId != $servicioId)',
        );
        return null;
      }
      final datos = local['datos'];
      if (datos is! Map) return null;
      AppLogger.d('✅ Restaurando servicio activo desde persistencia local');
      return {'servicio': Map<String, dynamic>.from(datos)};
    } catch (e) {
      AppLogger.d('⚠️ Persistencia local de servicio: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _normalizarDesdeNav(Map<String, dynamic> nav) {
    final servicio = nav['servicio'];
    if (servicio is! Map) return null;
    return ServicioPayloadAdapter.normalize(
      servicio: Map<String, dynamic>.from(servicio),
      pasajero: nav['pasajero'] is Map
          ? Map<String, dynamic>.from(nav['pasajero'] as Map)
          : null,
      conductor: nav['conductor'] is Map
          ? Map<String, dynamic>.from(nav['conductor'] as Map)
          : null,
      vehiculo: nav['vehiculo'] is Map
          ? Map<String, dynamic>.from(nav['vehiculo'] as Map)
          : null,
    );
  }
}
