import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class ReverseGeocodingService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static final RegExp _plusCodeRegex = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}$',
    caseSensitive: false,
  );

  Future<String?> resolveAreaName({
    required double lat,
    required double lng,
  }) async {
    final key = AppConfig.googleMapsApiKey.trim();
    if (key.isEmpty) return null;

    try {
      final url = Uri.parse(
        '$_baseUrl?latlng=$lat,$lng&key=$key&language=es&region=co',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      AppLogger.d('📍 GEOCODE RESPONSE: ${response.body}');
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>? ?? [];
      for (final item in results) {
        final result = item is Map<String, dynamic>
        
            ? item
            : Map<String, dynamic>.from(item as Map);
        final components = result['address_components'] as List<dynamic>? ?? [];
        final resultTypes = (result['types'] as List<dynamic>? ?? [])
    .map((e) => e.toString())
    .toList();

if (resultTypes.contains('plus_code') ||
    resultTypes.contains('postal_code') ||
    resultTypes.contains('administrative_area_level_2')) {
  continue;
}

        // 1) Prioridad alta: barrio/sector/localidad pequeña.
        final neighborhood = _firstComponentValue(
          components,
          acceptedTypes: const [
            'neighborhood',
            'sublocality',
            'sublocality_level_1',
            'sublocality_level_2',
            'sublocality_level_3',
          ],
        );
        if (neighborhood != null && neighborhood.isNotEmpty) {
          return neighborhood;
        }

        // 2) Si no hay barrio, usar vía o zona de calle.
        final route = _firstComponentValue(
          components,
          acceptedTypes: const [
            'route',
            'point_of_interest',
            'establishment',
            'street_address',
            'premise',
          ],
        );
        if (route != null &&
            route.isNotEmpty &&
            !_isCityLike(route) &&
            !_isPlusCodeLike(route)) {
          return route;
        }

        // Fallback por resultado: intentar extraer etiqueta humana desde plus_code.
        final resultPlusCode = result['plus_code'] is Map
            ? Map<String, dynamic>.from(result['plus_code'] as Map)
            : null;
        final compoundCode = resultPlusCode?['compound_code']?.toString();
        final fromCompound = _extractHumanAreaFromCompoundCode(compoundCode);
        if (fromCompound != null && fromCompound.isNotEmpty) {
          return fromCompound;
        }
      }

      // Fallback: usar dirección corta si no encontramos barrio/localidad.
      final first = results.isNotEmpty
          ? (results.first as Map<String, dynamic>)
          : null;
      final shortAddress = first?['formatted_address']?.toString();
      if (shortAddress == null || shortAddress.isEmpty) return null;
      final parts = shortAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      for (final part in parts) {
        if (_isPlusCodeLike(part)) continue;
        if (_isCityLike(part)) continue;
        return part;
      }

      // Último recurso: ciudad
      final city = _firstComponentValue(
        (first?['address_components'] as List<dynamic>? ?? []),
        acceptedTypes: const ['locality', 'administrative_area_level_2'],
      );
      return city;
    } catch (e) {
      AppLogger.d('⚠️ Error resolviendo zona por geocode: $e');
      return null;
    }
  }

  String? _firstComponentValue(
    List<dynamic> components, {
    required List<String> acceptedTypes,
  }) {
    for (final item in components) {
      final component = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      final types = (component['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final matches = acceptedTypes.any(types.contains);
      if (!matches) continue;
      final value =
          component['long_name']?.toString() ??
          component['short_name']?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _extractHumanAreaFromCompoundCode(String? compoundCode) {
    if (compoundCode == null || compoundCode.trim().isEmpty) return null;
    final cleaned = compoundCode.trim();
    final spaceIndex = cleaned.indexOf(' ');
    final withoutCode = spaceIndex > 0 ? cleaned.substring(spaceIndex + 1) : '';
    if (withoutCode.isEmpty) return null;
    final firstToken = withoutCode.split(',').first.trim();
    if (firstToken.isEmpty || _isPlusCodeLike(firstToken)) return null;
    return firstToken;
  }

  bool _isPlusCodeLike(String value) {
    final normalized = value.trim().toUpperCase();
    if (_plusCodeRegex.hasMatch(normalized)) return true;
    // Casos parciales que Google devuelve a veces: "+JR", "C9X6+JR", etc.
    if (normalized.startsWith('+')) return true;
    if (normalized.contains('+')) {
      final compact = normalized.replaceAll(' ', '');
      if (compact.length <= 10) return true;
    }
    return false;
  }

  bool _isCityLike(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    return v == 'popayán' || v == 'popayan' || v == 'cauca';
  }
}
