import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    final results = await _fetchGeocodeResults(lat: lat, lng: lng);
    if (results == null) return null;
    var area = _extractAreaFromResults(results);
    if (area != null) return area;

    final neighborhoodResults = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      resultType:
          'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
      logLabel: 'neighborhood',
    );
    if (neighborhoodResults == null) return null;
    return _extractAreaFromResults(neighborhoodResults);
  }

  /// Chip «Tu zona» del conductor: el nombre más útil entre varias etiquetas del mapa.
  ///
  /// Google suele devolver a la vez «Ruta Nacional 25» y «Timbío-Popayán»; priorizamos
  /// el tramo local / corredor sobre la numeración genérica de ruta nacional.
  Future<String?> resolveZonaConductor({
    required double lat,
    required double lng,
  }) async {
    final candidates = <String>{};

    final results = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      logLabel: 'zona',
    );
    if (results != null) {
      if (kDebugMode) {
        _logGeocodeRawResponse(lat: lat, lng: lng, results: results);
      }
      _collectZonaConductorCandidates(results, candidates);
    }

    final neighborhoodResults = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      resultType:
          'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
      logLabel: 'neighborhood',
    );
    if (neighborhoodResults != null) {
      _collectZonaConductorCandidates(neighborhoodResults, candidates);
    }

    if (candidates.isEmpty) {
      if (kDebugMode) {
        AppLogger.w(
          'Zona conductor: sin candidatos lat=$lat lng=$lng',
          tag: 'ZonaConductor',
        );
      }
      return null;
    }

    final picked = _pickBestZonaConductorLabel(candidates);
    if (kDebugMode) {
      _logZonaConductorPick(
        lat: lat,
        lng: lng,
        candidates: candidates,
        picked: picked,
      );
    }
    return picked;
  }

  void _collectZonaConductorCandidates(
    List<Map<String, dynamic>> results,
    Set<String> out,
  ) {
    const barrioTypes = [
      'neighborhood',
      'sublocality',
      'sublocality_level_1',
      'sublocality_level_2',
      'sublocality_level_3',
      'administrative_area_level_3',
    ];

    void addCandidate(String? value) {
      if (!_isValidZonaCandidate(value)) return;
      out.add(value!.trim());
    }

    for (final result in results) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      if (resultTypes.contains('plus_code') &&
          resultTypes.length == 1 &&
          !resultTypes.any(barrioTypes.contains)) {
        continue;
      }

      final components = result['address_components'] as List<dynamic>? ?? [];
      for (final item in components) {
        final component = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        final types = (component['types'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (types.contains('country') ||
            types.contains('administrative_area_level_1') ||
            types.contains('administrative_area_level_2') ||
            types.contains('continent')) {
          continue;
        }

        if (barrioTypes.any(types.contains)) {
          addCandidate(component['long_name']?.toString());
          addCandidate(component['short_name']?.toString());
        }

        if (types.contains('route')) {
          addCandidate(component['long_name']?.toString());
          addCandidate(component['short_name']?.toString());
        }

        if (types.contains('locality') || types.contains('postal_town')) {
          addCandidate(component['long_name']?.toString());
          addCandidate(component['short_name']?.toString());
        }
      }

      final formatted = result['formatted_address']?.toString();
      if (formatted != null && formatted.isNotEmpty) {
        for (final part in formatted.split(',')) {
          addCandidate(part.trim());
        }
      }

      final resultPlusCode = result['plus_code'] is Map
          ? Map<String, dynamic>.from(result['plus_code'] as Map)
          : null;
      addCandidate(
        _extractHumanAreaFromCompoundCode(
          resultPlusCode?['compound_code']?.toString(),
        ),
      );
    }
  }

  String? _pickBestZonaConductorLabel(Set<String> candidates) {
    String? best;
    var bestScore = -0x7fffffff;

    for (final label in candidates) {
      final score = _scoreZonaConductorLabel(label);
      if (score > bestScore) {
        bestScore = score;
        best = label;
      }
    }
    return best;
  }

  int _scoreZonaConductorLabel(String label) {
    final v = label.trim().toLowerCase();
    var score = 0;

    if (_isGenericNationalRouteName(v)) {
      score -= 80;
    }
    if (_isTooBroadGeographicName(v)) {
      score -= 120;
    }

    final hasPopayan = v.contains('popayán') || v.contains('popayan');
    final hasTimbio = v.contains('timbío') || v.contains('timbio');
    if (hasPopayan) score += 35;
    if (hasTimbio) score += 35;
    if (hasPopayan && hasTimbio) score += 55;
    if (v.contains('-') && (hasPopayan || hasTimbio)) score += 30;
    if (v.contains('–') && (hasPopayan || hasTimbio)) score += 30;

    const localRefs = [
      'el bordo',
      'cajete',
      'morro',
      'vinagrón',
      'vinagron',
      'coconuco',
      'silvia',
      'puracé',
      'purace',
    ];
    for (final ref in localRefs) {
      if (v.contains(ref)) score += 18;
    }

    if (!_isGenericNationalRouteName(v) && !_looksLikeStreetName(label)) {
      score += 14;
    }

    if (label.length >= 6 && label.length <= 48) score += 6;

    return score;
  }

  bool _isGenericNationalRouteName(String v) {
    return RegExp(r'^ruta\s+nacional\s*\d').hasMatch(v) ||
        RegExp(r'^rn\s*\d').hasMatch(v) ||
        v.startsWith('ruta nacional ');
  }

  /// Dirección formateada para un punto (ej. destino final al cerrar viaje).
  Future<String?> resolveFormattedAddress({
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
      if (results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      return first['formatted_address']?.toString();
    } catch (e) {
      AppLogger.d('⚠️ Error resolviendo dirección formateada: $e');
      return null;
    }
  }

  /// Devuelve nombre corto y legible para mostrar como origen (barrio + calle).
  Future<CurrentLocationData> resolveCurrentLocationLabel({
    required double lat,
    required double lng,
  }) async {
    const fallback = CurrentLocationData(
      name: 'Mi ubicación',
      address: 'Ubicación actual',
    );

    final results = await _fetchGeocodeResults(lat: lat, lng: lng);
    if (results == null || results.isEmpty) return fallback;

    var area = _extractAreaFromResults(results);
    if (area == null) {
      final neighborhoodResults = await _fetchGeocodeResults(
        lat: lat,
        lng: lng,
        resultType:
            'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
        logLabel: 'neighborhood',
      );
      if (neighborhoodResults != null && neighborhoodResults.isNotEmpty) {
        area = _extractAreaFromResults(neighborhoodResults);
      }
    }

    final streetLine = _extractStreetLineFromResults(results);
    final fullAddress = _extractFormattedAddress(results);

    if (kDebugMode) {
      _logResolvedLocation(
        lat: lat,
        lng: lng,
        area: area,
        streetLine: streetLine,
        fullAddress: fullAddress,
      );
    }

    // Prioridad: barrio como etiqueta principal (lo que ve el pasajero).
    final String displayName;
    if (area != null && area.isNotEmpty) {
      displayName = area;
    } else if (streetLine != null && streetLine.isNotEmpty) {
      displayName = streetLine;
    } else {
      displayName = 'Mi ubicación';
    }

    return CurrentLocationData(
      name: displayName,
      address: fullAddress ?? displayName,
      area: area,
      streetLine: streetLine,
    );
  }

  Future<List<Map<String, dynamic>>?> _fetchGeocodeResults({
    required double lat,
    required double lng,
    String? resultType,
    String logLabel = 'default',
  }) async {
    final key = AppConfig.googleMapsApiKey.trim();
    if (key.isEmpty) return null;

    try {
      final query = StringBuffer(
        'latlng=$lat,$lng&key=$key&language=es&region=co',
      );
      if (resultType != null && resultType.isNotEmpty) {
        query.write('&result_type=$resultType');
      }

      final url = Uri.parse('$_baseUrl?$query');
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? 'UNKNOWN';
      if (status != 'OK') {
        if (kDebugMode && logLabel == 'default') {
          AppLogger.w(
            'Geocode status=$status lat=$lat lng=$lng error=${data['error_message']}',
            tag: 'ReverseGeocode',
          );
        }
        return null;
      }

      final raw = data['results'] as List<dynamic>? ?? [];
      final results = raw
          .map(
            (item) => item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map),
          )
          .toList();

      if (kDebugMode && logLabel == 'default') {
        _logGeocodeRawResponse(lat: lat, lng: lng, results: results);
      } else if (kDebugMode && results.isNotEmpty) {
        AppLogger.d(
          'Geocode [$logLabel] lat=$lat lng=$lng → ${results.length} resultados',
          tag: 'ReverseGeocode',
        );
        for (var i = 0; i < results.length && i < 3; i++) {
          final r = results[i];
          final types = (r['types'] as List? ?? []).join(',');
          AppLogger.d(
            '  [$logLabel][$i] types=$types formatted=${r['formatted_address']}',
            tag: 'ReverseGeocode',
          );
        }
      }

      return results;
    } catch (e) {
      AppLogger.d('⚠️ Error en geocode reverso: $e');
      return null;
    }
  }

  String? _extractAreaFromResults(List<Map<String, dynamic>> results) {
    const barrioTypes = [
      'neighborhood',
      'sublocality',
      'sublocality_level_1',
      'sublocality_level_2',
      'sublocality_level_3',
      'administrative_area_level_3',
    ];

    for (final result in results) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      if (resultTypes.contains('plus_code') ||
          resultTypes.contains('postal_code')) {
        continue;
      }

      final components = result['address_components'] as List<dynamic>? ?? [];
      for (final item in components) {
        final component = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        final types = (component['types'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        final isBarrioType = barrioTypes.any(types.contains);
        if (!isBarrioType) continue;

        final value =
            component['long_name']?.toString() ??
            component['short_name']?.toString();
        if (_isValidBarrioCandidate(value)) {
          return value!.trim();
        }
      }

      // Resultado filtrado por result_type=neighborhood: usar formatted_address.
      if (resultTypes.any(barrioTypes.contains)) {
        final formatted = result['formatted_address']?.toString();
        if (_isValidBarrioCandidate(formatted)) {
          return formatted!.split(',').first.trim();
        }
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

  String? _extractStreetLineFromResults(List<Map<String, dynamic>> results) {
    String? streetName;
    String? streetNumber;

    bool isStreetResult(List<String> types) {
      if (types.contains('street_address')) return true;
      if (types.contains('premise') && !types.contains('establishment')) {
        return true;
      }
      return types.contains('route') &&
          !types.contains('establishment') &&
          !types.contains('lodging') &&
          !types.contains('point_of_interest');
    }

    for (final result in results) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (resultTypes.length == 1 && resultTypes.contains('plus_code')) {
        continue;
      }
      if (!isStreetResult(resultTypes)) continue;

      final components = result['address_components'] as List<dynamic>? ?? [];
      streetName ??= _firstComponentValue(
        components,
        acceptedTypes: const ['route'],
      );
      streetNumber ??= _firstComponentValue(
        components,
        acceptedTypes: const ['street_number'],
      );

      if (streetName != null) break;
    }

    // Respaldo: cualquier resultado con route (excepto plus_code puro).
    if (streetName == null) {
      for (final result in results) {
        final resultTypes = (result['types'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        if (resultTypes.contains('plus_code') &&
            !resultTypes.contains('route')) {
          continue;
        }
        final components = result['address_components'] as List<dynamic>? ?? [];
        streetName ??= _firstComponentValue(
          components,
          acceptedTypes: const ['route'],
        );
        streetNumber ??= _firstComponentValue(
          components,
          acceptedTypes: const ['street_number'],
        );
        if (streetName != null) break;
      }
    }

    return _formatStreetLine(streetName, streetNumber);
  }

  String? _extractFormattedAddress(List<Map<String, dynamic>> results) {
    for (final result in results) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!resultTypes.contains('street_address')) continue;
      final formatted = result['formatted_address']?.toString() ?? '';
      final cleaned = _stripPlusCodes(formatted);
      if (cleaned.isNotEmpty) return cleaned;
    }

    for (final result in results) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (resultTypes.length == 1 && resultTypes.contains('plus_code')) {
        continue;
      }
      if (resultTypes.contains('establishment') ||
          resultTypes.contains('lodging') ||
          resultTypes.contains('point_of_interest')) {
        continue;
      }
      final formatted = result['formatted_address']?.toString() ?? '';
      final cleaned = _stripPlusCodes(formatted);
      if (cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  String? _formatStreetLine(String? route, String? number) {
    if (route == null || route.trim().isEmpty) return null;
    var street = route.trim();
    var num = number?.trim() ?? '';
    while (num.startsWith('#')) {
      num = num.substring(1).trim();
    }
    while (street.endsWith('#')) {
      street = street.substring(0, street.length - 1).trim();
    }
    if (num.isEmpty) return street;
    return '$street #$num';
  }

  bool _isValidBarrioCandidate(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.length < 3) return false;
    if (_isPlusCodeLike(v)) return false;
    if (_isCityLike(v)) return false;
    if (_looksLikeStreetName(v)) return false;
    if (_looksLikeSubpremise(v)) return false;
    if (RegExp(r'^\d+$').hasMatch(v)) return false;
    return true;
  }

  bool _isValidZonaCandidate(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.length < 2) return false;
    if (_isPlusCodeLike(v)) return false;
    if (_isCityLike(v)) return false;
    if (_isTooBroadGeographicName(v)) return false;
    if (_looksLikeSubpremise(v)) return false;
    if (RegExp(r'^\d+$').hasMatch(v)) return false;
    return true;
  }

  /// País, departamento u otras etiquetas demasiado amplias para el chip.
  bool _isTooBroadGeographicName(String value) {
    final v = value.trim().toLowerCase();
    const blocked = {
      'colombia',
      'cauca',
      'departamento del cauca',
      'suramérica',
      'sur america',
      'south america',
      'américa del sur',
      'america del sur',
    };
    if (blocked.contains(v)) return true;
    if (v == 'co' || v.length <= 2) return true;
    return false;
  }

  bool _looksLikeSubpremise(String value) {
    final v = value.trim().toLowerCase();
    if (v.contains('##')) return true;
    if (RegExp(r'^a\s+\d').hasMatch(v)) return true;
    if (RegExp(r'^#\s*\d').hasMatch(v)) return true;
    if (RegExp(r'^\d+[\-–]\d+').hasMatch(v)) return true;
    return false;
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

  bool _looksLikeStreetName(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    return RegExp(
      r'^(calle|carrera|cr\.?|cl\.?|av\.?|avenida|diag\.?|diagonal|trans\.?|transversal|km\.?)\b',
    ).hasMatch(v);
  }

  void _logZonaConductorPick({
    required double lat,
    required double lng,
    required Set<String> candidates,
    required String? picked,
  }) {
    final ranked = candidates
        .map((c) => MapEntry(c, _scoreZonaConductorLabel(c)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer()
      ..writeln('══════════════════════════════════════════')
      ..writeln('📍 ZONA CONDUCTOR lat=$lat lng=$lng')
      ..writeln('   elegido: ${picked ?? "—"}')
      ..writeln('   candidatos (${ranked.length}):');

    for (final entry in ranked) {
      final mark = entry.key == picked ? ' ← ELEGIDO' : '';
      buffer.writeln('   · [${entry.value}] ${entry.key}$mark');
    }
    buffer.writeln('══════════════════════════════════════════');
    AppLogger.d(buffer.toString(), tag: 'ZonaConductor');
  }

  void _logGeocodeRawResponse({
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> results,
  }) {
    final buffer = StringBuffer()
      ..writeln('══════════════════════════════════════════')
      ..writeln('📍 REVERSE GEOCODE lat=$lat lng=$lng')
      ..writeln('   resultados=${results.length}');

    for (var i = 0; i < results.length && i < 6; i++) {
      final result = results[i];
      final types = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .join(', ');
      buffer
        ..writeln('── resultado[$i] types: $types')
        ..writeln('   formatted: ${result['formatted_address']}');

      final plusCode = result['plus_code'];
      if (plusCode is Map) {
        buffer.writeln(
          '   plus_code: global=${plusCode['global_code']} compound=${plusCode['compound_code']}',
        );
      }

      final components = result['address_components'] as List<dynamic>? ?? [];
      for (final item in components) {
        final c = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map);
        final cTypes = (c['types'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .join('|');
        buffer.writeln(
          '   · ${c['long_name']} (${c['short_name']}) ← $cTypes',
        );
      }
    }

    buffer.writeln('══════════════════════════════════════════');
    AppLogger.d(buffer.toString(), tag: 'ReverseGeocode');
  }

  void _logResolvedLocation({
    required double lat,
    required double lng,
    required String? area,
    required String? streetLine,
    required String? fullAddress,
  }) {
    AppLogger.i(
      '✅ RESUELTO lat=$lat lng=$lng | barrio=${area ?? "—"} | calle=${streetLine ?? "—"} | address=${fullAddress ?? "—"}',
      tag: 'ReverseGeocode',
    );
  }
}

class CurrentLocationData {
  final String name;
  final String address;
  final String? area;
  final String? streetLine;

  const CurrentLocationData({
    required this.name,
    required this.address,
    this.area,
    this.streetLine,
  });

  /// Etiqueta corta para recogida: barrio primero, calle como detalle.
  String get pickupLabel {
    final barrio = area?.trim();
    if (barrio != null && barrio.isNotEmpty) return 'Barrio: $barrio';
    return name;
  }

  String get pickupSubtitle {
    final barrio = area?.trim();
    final calle = streetLine?.trim();
    if (barrio != null && barrio.isNotEmpty && calle != null && calle.isNotEmpty) {
      return calle;
    }
    if (address.trim().isNotEmpty && address != name) return address;
    return '';
  }
}