import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/geo/barrios/barrios_catalog.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Cliente Laravel `taxi/barrios/*`. Si el backend no está desplegado,
/// [BarrioResolver] usa el catálogo local.
class BarriosApiService {
  BarriosApiService({Dio? dio}) : _dio = dio ?? DioClient.getInstance();

  final Dio _dio;

  Future<BarrioResolveResult?> resolve(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'taxi/barrios/resolve',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) return null;
      return _parseResolve(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      AppLogger.d('barrios/resolve: ${e.message}', tag: 'BarriosApi');
      return null;
    }
  }

  Future<List<Barrio>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final res = await _dio.get(
        'taxi/barrios',
        queryParameters: {'q': q, 'limit': 20},
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) return const [];
      final list = data['barrios'] as List? ?? const [];
      return [
        for (final item in list)
          if (item is Map)
            Barrio.fromJson({
              ...Map<String, dynamic>.from(item),
              'polygons': item['polygons'] ?? const [],
              'bbox': item['bbox'] ?? const [0, 0, 0, 0],
            }),
      ];
    } on DioException catch (e) {
      AppLogger.d('barrios search: ${e.message}', tag: 'BarriosApi');
      return const [];
    }
  }

  BarrioResolveResult _parseResolve(Map<String, dynamic> data) {
    final kindName = data['kind']?.toString();
    final kind = switch (kindName) {
      'inside' => BarrioResolveKind.inside,
      'near_border' => BarrioResolveKind.nearBorder,
      'nearby' => BarrioResolveKind.nearby,
      _ => BarrioResolveKind.unknown,
    };
    Barrio? match;
    final matchJson = data['barrio'];
    if (matchJson is Map) {
      match = Barrio.fromJson({
        ...Map<String, dynamic>.from(matchJson),
        'polygons': matchJson['polygons'] ?? const [],
        'bbox': matchJson['bbox'] ?? const [0, 0, 0, 0],
      });
    }
    final candidates = <Barrio>[];
    for (final item in data['candidatos'] as List? ?? const []) {
      if (item is! Map) continue;
      candidates.add(
        Barrio.fromJson({
          ...Map<String, dynamic>.from(item),
          'polygons': item['polygons'] ?? const [],
          'bbox': item['bbox'] ?? const [0, 0, 0, 0],
        }),
      );
    }
    return BarrioResolveResult(
      kind: kind,
      match: match,
      candidates: candidates,
      distanceToBoundaryM: (data['distancia_borde_m'] as num?)?.toDouble(),
    );
  }
}

class BarrioResolver {
  BarrioResolver({
    BarriosApiService? api,
  }) : _api = api ?? BarriosApiService();

  final BarriosApiService _api;

  Future<BarrioResolveResult> resolve(double lat, double lng) async {
    final remote = await _api.resolve(lat, lng);
    if (remote != null) return remote;
    final catalog = await BarriosCatalog.instance();
    return catalog.resolve(lat, lng);
  }

  Future<List<Barrio>> search(String query) async {
    final remote = await _api.search(query);
    if (remote.isNotEmpty) return remote;
    final catalog = await BarriosCatalog.instance();
    return catalog.search(query);
  }
}
