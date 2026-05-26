import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/emergencias/providers/emergencia_provider.dart';
import 'package:intellitaxi/features/emergencias/utils/emergencia_report_helper.dart';

/// Envío de emergencia en un paso (solo lat/lng; el backend geocodifica).
class EmergenciaQuickReport {
  EmergenciaQuickReport._();

  static Future<EmergenciaQuickReportResult> enviar({
    required BuildContext context,
    bool mostrarSnackBar = true,
  }) async {
    final emergenciaProvider = context.read<EmergenciaProvider>();
    if (emergenciaProvider.isLoading) {
      return const EmergenciaQuickReportResult(
        ok: false,
        mensaje: 'Envío en curso…',
      );
    }
    if (emergenciaProvider.estaEnEmergencia) {
      return const EmergenciaQuickReportResult(
        ok: false,
        mensaje: 'Ya tienes una emergencia activa',
      );
    }

    final auth = context.read<AuthProvider>();
    final conductor = context.read<ConductorHomeProvider>();
    final turno = conductor.turnoActivo;
    final vehiculo = conductor.vehiculoSeleccionado;

    if (auth.user?.id == null) {
      return const EmergenciaQuickReportResult(
        ok: false,
        mensaje: 'No se pudo identificar al conductor',
      );
    }
    if (turno == null) {
      return const EmergenciaQuickReportResult(
        ok: false,
        mensaje: 'Activa un turno para pedir apoyo',
      );
    }

    final position = await EmergenciaReportHelper.resolveCoords(conductor);
    if (position == null) {
      return const EmergenciaQuickReportResult(
        ok: false,
        mensaje: 'No se pudo obtener tu ubicación',
      );
    }

    final ok = await emergenciaProvider.enviarApoyoRapido(
      idVehiculo: vehiculo?.id ?? turno.idVehiculo,
      idTurno: turno.id,
      lat: position.latitude,
      lng: position.longitude,
      placa: vehiculo?.placa,
    );

    final mensaje = ok
        ? 'Apoyo enviado. La central recibió tu ubicación.'
        : emergenciaProvider.lastError ?? 'Error al enviar';

    if (mostrarSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: ok ? 3 : 4),
          content: Text(mensaje),
        ),
      );
    }

    return EmergenciaQuickReportResult(
      ok: ok,
      mensaje: mensaje,
      lat: position.latitude,
      lng: position.longitude,
    );
  }
}

class EmergenciaQuickReportResult {
  const EmergenciaQuickReportResult({
    required this.ok,
    required this.mensaje,
    this.lat,
    this.lng,
  });

  final bool ok;
  final String mensaje;
  final double? lat;
  final double? lng;
}
