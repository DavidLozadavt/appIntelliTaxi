import 'package:dio/dio.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/taxi/data/motivos_cancelacion.dart';

/// `GET motivos-cancelacion` y `POST servicio/cancelar` (motivo opcional).
class TaxiServicioCancelacionService {
  TaxiServicioCancelacionService(this._dio);

  final Dio _dio;

  static const _cancelarPath = 'taxi/servicio/cancelar';
  static const _motivosPath = 'taxi/servicio/motivos-cancelacion';

  Future<MotivosCancelacionCatalog> obtenerMotivos() async {
    try {
      final response = await _dio.get(_motivosPath);
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return MotivosCancelacionCatalog.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
    } on DioException catch (e) {
      AppLogger.d('⚠️ motivos-cancelacion: ${e.message}');
    } catch (e) {
      AppLogger.d('⚠️ motivos-cancelacion: $e');
    }
    return MotivosCancelacionCatalog.fallback;
  }

  Future<Map<String, dynamic>> cancelar({
    required int servicioId,
    String? motivoCodigo,
    String? motivo,
  }) async {
    final body = <String, dynamic>{'servicio_id': servicioId};

    final texto = motivo?.trim();
    if (texto != null && texto.isNotEmpty) {
      body['motivo'] = texto;
    } else {
      final codigo = motivoCodigo?.trim();
      if (codigo != null && codigo.isNotEmpty) {
        body['motivo_codigo'] = codigo;
      }
    }

    AppLogger.d('📤 POST $_cancelarPath → $body');

    final response = await _dio.post(_cancelarPath, data: body);
    final raw = response.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {'success': true, 'servicio_id': servicioId};
  }
}
