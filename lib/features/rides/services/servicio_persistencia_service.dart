import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para persistir el estado de servicios activos
/// Permite que la app recupere el estado del servicio después de cerrarla
class ServicioPersistenciaService {
  static const String _keyServicioActivoData = 'servicio_activo_data';
  static const String _keyServicioActivoTipo =
      'servicio_activo_tipo'; // 'conductor' o 'pasajero'
  static const String _keyServicioActivoId = 'servicio_activo_id';

  /// Guarda los datos del servicio activo
  Future<void> guardarServicioActivo({
    required int servicioId,
    required String tipo, // 'conductor' o 'pasajero'
    required Map<String, dynamic> datosServicio,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_keyServicioActivoId, servicioId);
      await prefs.setString(_keyServicioActivoTipo, tipo);
      await prefs.setString(_keyServicioActivoData, jsonEncode(datosServicio));

      print('✅ Servicio activo guardado: ID=$servicioId, Tipo=$tipo');
    } catch (e) {
      print('⚠️ Error guardando servicio activo: $e');
    }
  }

  /// Recupera los datos del servicio activo
  Future<Map<String, dynamic>?> obtenerServicioActivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final servicioId = prefs.getInt(_keyServicioActivoId);
      final tipo = prefs.getString(_keyServicioActivoTipo);
      final dataJson = prefs.getString(_keyServicioActivoData);

      if (servicioId == null || tipo == null || dataJson == null) {
        print('ℹ️ No hay servicio activo guardado');
        return null;
      }

      final datosServicio = jsonDecode(dataJson) as Map<String, dynamic>;

      print('✅ Servicio activo recuperado: ID=$servicioId, Tipo=$tipo');

      return {'servicioId': servicioId, 'tipo': tipo, 'datos': datosServicio};
    } catch (e) {
      print('⚠️ Error recuperando servicio activo: $e');
      return null;
    }
  }

  /// Limpia los datos del servicio activo
  Future<void> limpiarServicioActivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyServicioActivoId);
      await prefs.remove(_keyServicioActivoTipo);
      await prefs.remove(_keyServicioActivoData);

      print('🗑️ Datos del servicio activo limpiados');
    } catch (e) {
      print('⚠️ Error limpiando servicio activo: $e');
    }
  }

  /// Verifica si hay un servicio activo guardado
  Future<bool> tieneServicioActivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keyServicioActivoId);
    } catch (e) {
      print('⚠️ Error verificando servicio activo: $e');
      return false;
    }
  }
}
