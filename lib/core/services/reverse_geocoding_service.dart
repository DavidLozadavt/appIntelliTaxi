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

        final resultPlusCode = result['plus_code'] is Map
            ? Map<String, dynamic>.from(result['plus_code'] as Map)
            : null;
        final compoundCode = resultPlusCode?['compound_code']?.toString();
        final fromCompound = _extractHumanAreaFromCompoundCode(compoundCode);
        if (fromCompound != null && fromCompound.isNotEmpty) {
          return fromCompound;
        }
      }

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

  /// Devuelve nombre corto y legible para mostrar como origen (calle + barrio)
  Future<CurrentLocationData> resolveCurrentLocationLabel({
    required double lat,
    required double lng,
  }) async {
    const fallback = CurrentLocationData(
      name: 'Mi ubicación',
      address: 'Ubicación actual',
    );

    final key = AppConfig.googleMapsApiKey.trim();
    if (key.isEmpty) return fallback;

    try {
      final url = Uri.parse(
        '$_baseUrl?latlng=$lat,$lng&key=$key&language=es&region=co',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return fallback;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return fallback;

      final results = data['results'] as List<dynamic>? ?? [];

      String? streetName;
      String? streetNumber;
      String? neighborhood;
      String? fullAddress;

      for (final item in results) {
        final result = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);

        final resultTypes = (result['types'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        // Saltar resultados que son solo plus_code
        if (resultTypes.length == 1 && resultTypes.contains('plus_code')) {
          continue;
        }

        final components = result['address_components'] as List<dynamic>? ?? [];

        streetName ??= _firstComponentValue(
          components,
          acceptedTypes: const ['route', 'street_address'],
        );

        streetNumber ??= _firstComponentValue(
          components,
          acceptedTypes: const ['street_number'],
        );

        neighborhood ??= _firstComponentValue(
          components,
          acceptedTypes: const [
            'neighborhood',
            'sublocality_level_1',
            'sublocality',
          ],
        );

        if (fullAddress == null) {
          final formatted = result['formatted_address']?.toString() ?? '';
          final cleaned = _stripPlusCodes(formatted);
          if (cleaned.isNotEmpty) fullAddress = cleaned;
        }

        // Con calle + barrio es suficiente, no seguir iterando
        if (streetName != null && neighborhood != null) break;
      }

      // Construir nombre para mostrar en el campo origen
      final String displayName;
      if (streetName != null && streetNumber != null && neighborhood != null) {
        displayName = '$streetName $streetNumber, $neighborhood';
      } else if (streetName != null && neighborhood != null) {
        displayName = '$streetName, $neighborhood';
      } else if (streetName != null && streetNumber != null) {
        displayName = '$streetName $streetNumber';
      } else if (streetName != null) {
        displayName = streetName;
      } else if (neighborhood != null) {
        displayName = neighborhood;
      } else {
        displayName = 'Mi ubicación';
      }

      return CurrentLocationData(
        name: displayName,
        address: fullAddress ?? displayName,
      );
    } catch (e) {
      AppLogger.d('⚠️ Error resolviendo nombre de ubicación actual: $e');
      return fallback;
    }
  }

  String _stripPlusCodes(String address) {
    return address
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9]{4,8}\+[A-Z0-9]{2,3}\b,?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
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

class CurrentLocationData {
  final String name;
  final String address;

  const CurrentLocationData({required this.name, required this.address});
}