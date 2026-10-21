import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/geo/place_precision.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/geocode_memory_cache.dart';
import 'package:intellitaxi/features/taxi/data/taxi_maps_models.dart';
import 'package:intellitaxi/features/taxi/services/taxi_maps_api_service.dart';

class ReverseGeocodingService {
  ReverseGeocodingService._();
  static final ReverseGeocodingService shared = ReverseGeocodingService._();
  factory ReverseGeocodingService() => shared;

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const Duration _fetchCacheTtl = Duration(hours: 6);
  static const Duration _zonaLabelCacheTtl = Duration(hours: 4);
  static const Duration _labelCacheTtl = Duration(hours: 6);

  final GeocodeMemoryCache _cache = GeocodeMemoryCache.instance;
  TaxiMapsApiService? _taxiMapsProxy;
  TaxiMapsApiService get _taxiMaps =>
      _taxiMapsProxy ??= TaxiMapsApiService(DioClient.getInstance());

  static final RegExp _plusCodeRegex = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}$',
    caseSensitive: false,
  );

  /// Distancia máxima (m) entre el punto consultado y la respuesta del proxy
  /// para aceptar su barrio.
  ///
  /// El geocoder del backend engancha el punto a la vía más cercana (10-60 m
  /// normalmente). Con 750 m se aceptaban barrios de otros sectores; con
  /// 150 m solo se acepta el barrio real del punto.
  static const double _proxyMaxAcceptableDistanceMeters = 150;

  /// Distancia (m) dentro de la cual se reutiliza un barrio ya resuelto en
  /// lugar de volver a preguntar. Evita una llamada por cada 11 m recorridos.
  static const double _areaLabelReuseMeters = 60;

  /// Barrios ya resueltos, para reutilizar el más cercano.
  final List<({double lat, double lng, String barrio})> _areaLabelPoints = [];

  bool _proxyResultIsAligned(
    double lat,
    double lng,
    TaxiReverseGeocodeResult r,
  ) {
    final meters = Geolocator.distanceBetween(lat, lng, r.lat, r.lng);
    if (meters <= _proxyMaxAcceptableDistanceMeters) return true;
    if (kDebugMode) {
      AppLogger.d(
        'Proxy geocode desalineado (${meters.round()} m) lat=$lat lng=$lng '
        '→ se usa Google en su lugar',
        tag: 'ReverseGeocode',
      );
    }
    return false;
  }

  Future<String?> resolveAreaName({
    required double lat,
    required double lng,
  }) async {
    // Cuadrícula fina (~11 m): un barrio de Popayán puede medir 200 m y
    // una celda de 111 m cruzaba la frontera entre dos barrios.
    final labelKey =
        'area|${GeocodeMemoryCache.gridKey(lat, lng, decimals: 4)}';
    final cached = _cache.get<String>(labelKey);
    if (cached != null) return cached;

    // Reutiliza el barrio ya conocido más cercano (misma zona, sin gastar
    // una llamada de red por cada pocos metros recorridos).
    final nearby = _nearestKnownAreaLabel(lat, lng);
    if (nearby != null) {
      _cache.put(labelKey, nearby, _zonaLabelCacheTtl);
      return nearby;
    }

    // Etiqueta de zona del proxy ("Centro", "Comuna 4"): sirve de respaldo
    // si ninguna fuente da un barrio real, pero nunca gana contra uno.
    String? weakArea;

    if (MapsConfig.useBackendProxy) {
      final r = await _taxiMaps.reverseGeocode(lat, lng);
      final barrio = PlacePrecision.normalizeNeighborhood(r?.barrio);
      if (barrio.isNotEmpty &&
          PlacePrecision.isPlausibleNeighborhood(barrio) &&
          _proxyResultIsAligned(lat, lng, r!)) {
        _rememberAreaLabel(lat, lng, barrio);
        _cache.put(labelKey, barrio, _zonaLabelCacheTtl);
        return barrio;
      }
      if (PlacePrecision.isPlausibleZoneLabel(barrio)) {
        weakArea = barrio;
      }
      // Sin barrio o sector desalineado: se cae a Google más abajo.
    }

    // Google ya consultado en esta celda (sin gastar otra llamada).
    final fromCachedFetch = _areaFromCachedFetch(lat, lng);
    if (fromCachedFetch != null) {
      _rememberAreaLabel(lat, lng, fromCachedFetch);
      _cache.put(labelKey, fromCachedFetch, _zonaLabelCacheTtl);
      return fromCachedFetch;
    }

    final results = await _fetchGeocodeResults(lat: lat, lng: lng);
    if (results == null) return weakArea;
    var area = _extractAreaFromResults(results, lat: lat, lng: lng);
    if (area != null) {
      _rememberAreaLabel(lat, lng, area);
      _cache.put(labelKey, area, _zonaLabelCacheTtl);
      return area;
    }

    final neighborhoodResults = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      resultType:
          'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
      logLabel: 'neighborhood',
    );
    if (neighborhoodResults == null) return weakArea;
    area = _extractAreaFromResults(neighborhoodResults, lat: lat, lng: lng);
    if (area != null) {
      _rememberAreaLabel(lat, lng, area);
      _cache.put(labelKey, area, _zonaLabelCacheTtl);
      return area;
    }
    return weakArea;
  }

  /// Barrio ya resuelto más cercano al punto (dentro de [_areaLabelReuseMeters]).
  String? _nearestKnownAreaLabel(double lat, double lng) {
    String? best;
    var bestDistance = double.infinity;
    for (final point in _areaLabelPoints) {
      final distance = PlacePrecision.distanceMeters(
        lat,
        lng,
        point.lat,
        point.lng,
      );
      if (distance > _areaLabelReuseMeters) continue;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point.barrio;
      }
    }
    return best;
  }

  void _rememberAreaLabel(double lat, double lng, String barrio) {
    _areaLabelPoints.add((lat: lat, lng: lng, barrio: barrio));
    if (_areaLabelPoints.length > 60) {
      _areaLabelPoints.removeAt(0);
    }
  }

  /// Chip «Tu zona» del conductor: el nombre más útil entre varias etiquetas del mapa.
  ///
  /// Google suele devolver a la vez «Ruta Nacional 25» y «Timbío-Popayán»; priorizamos
  /// el tramo local / corredor sobre la numeración genérica de ruta nacional.
  Future<String?> resolveZonaConductor({
    required double lat,
    required double lng,
  }) async {
    // El chip debe coincidir con inDrive: Google Geocoding (calle), no el
    // barrio que a veces manda el ERP. Se llama poco (caché + umbral de metros).

    // Cuadrícula fina (~11 m) para calles distintas; caché evita repetir la API.
    final zonaKey = 'zona2|${GeocodeMemoryCache.gridKey(lat, lng, decimals: 4)}';
    final cachedZona = _cache.get<String>(zonaKey);
    if (cachedZona != null) return cachedZona;

    final streetResults = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      resultType: 'street_address|premise|subpremise|route',
      logLabel: 'zona_street',
    );
    if (streetResults != null && streetResults.isNotEmpty) {
      final streetLine = _extractStreetFromNearestGeocodeResult(
        streetResults,
        lat: lat,
        lng: lng,
      );
      if (streetLine != null && streetLine.trim().isNotEmpty) {
        final barrio = await _barrioLabelForZona(
          lat: lat,
          lng: lng,
          already: streetResults,
        );
        final label = _composeConductorZonaChip(
          street: streetLine,
          barrio: barrio,
        );
        if (kDebugMode) {
          AppLogger.d(
            'Zona conductor: $label ← $streetLine lat=$lat lng=$lng',
            tag: 'ZonaConductor',
          );
        }
        _cache.put(zonaKey, label, _zonaLabelCacheTtl);
        return label;
      }
    }

    final results = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      logLabel: 'zona',
    );
    if (results == null || results.isEmpty) {
      if (kDebugMode) {
        AppLogger.w(
          'Zona conductor: sin candidatos lat=$lat lng=$lng',
          tag: 'ZonaConductor',
        );
      }
      return null;
    }

    if (kDebugMode) {
      _logGeocodeRawResponse(lat: lat, lng: lng, results: results);
    }

    final streetLine = _extractStreetLineFromResults(results, lat: lat, lng: lng);
    if (streetLine != null && streetLine.trim().isNotEmpty) {
      final barrio = await _barrioLabelForZona(
        lat: lat,
        lng: lng,
        already: results,
      );
      final label = _composeConductorZonaChip(
        street: streetLine,
        barrio: barrio,
      );
      _cache.put(zonaKey, label, _zonaLabelCacheTtl);
      return label;
    }

    final candidates = <String>{};
    _collectZonaConductorBarrioCandidates(results, candidates);

    if (candidates.isEmpty) {
      final neighborhoodResults = await _fetchGeocodeResults(
        lat: lat,
        lng: lng,
        resultType:
            'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
        logLabel: 'neighborhood',
      );
      if (neighborhoodResults != null) {
        _collectZonaConductorBarrioCandidates(neighborhoodResults, candidates);
      }
    }

    if (candidates.isNotEmpty) {
      final picked = _pickBestZonaConductorLabel(candidates);
      if (kDebugMode) {
        _logZonaConductorPick(
          lat: lat,
          lng: lng,
          candidates: candidates,
          picked: picked,
        );
      }
      if (picked != null) {
        _cache.put(zonaKey, picked, _zonaLabelCacheTtl);
        return picked;
      }
    }

    final formatted = _extractFormattedAddress(results, lat: lat, lng: lng);
    if (formatted != null && formatted.trim().isNotEmpty) {
      final first = formatted.split(',').first.trim();
      if (first.length >= 3 && !_plusCodeRegex.hasMatch(first)) {
        final label = _looksLikeStreetName(first)
            ? compactStreetLabelForZona(first)
            : first;
        _cache.put(zonaKey, label, _zonaLabelCacheTtl);
        return label;
      }
    }

    final area = await resolveAreaName(lat: lat, lng: lng);
    if (area != null && area.trim().isNotEmpty) {
      _cache.put(zonaKey, area.trim(), _zonaLabelCacheTtl);
      return area.trim();
    }

    return null;
  }

  /// «Cl. 15 · Los Alamos de Occidente» cuando hay barrio; si no, solo la calle.
  String _composeConductorZonaChip({
    required String street,
    String? barrio,
  }) {
    final compact = compactStreetLabelForZona(street);
    final b = PlacePrecision.normalizeNeighborhood(barrio);
    if (b.isEmpty || !PlacePrecision.isPlausibleNeighborhood(b)) {
      return compact;
    }
    final streetFold = compact.toLowerCase();
    final barrioFold = b.toLowerCase();
    if (streetFold.contains(barrioFold) || barrioFold.contains(streetFold)) {
      return compact;
    }
    return '$compact · $b';
  }

  Future<String?> _barrioLabelForZona({
    required double lat,
    required double lng,
    List<Map<String, dynamic>>? already,
  }) async {
    final fromStreet = already == null || already.isEmpty
        ? null
        : _extractAreaFromResults(already, lat: lat, lng: lng);
    if (fromStreet != null &&
        PlacePrecision.isPlausibleNeighborhood(fromStreet)) {
      return fromStreet;
    }

    final neighborhoodResults = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      resultType:
          'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
      logLabel: 'zona_barrio',
    );
    if (neighborhoodResults == null || neighborhoodResults.isEmpty) {
      return fromStreet;
    }
    return _extractAreaFromResults(neighborhoodResults, lat: lat, lng: lng);
  }

  /// Etiqueta corta para chip «Zona:» (ej. Carrera 20b → Cra. 20b).
  static String compactStreetLabelForZona(String streetLine) {
    var s = streetLine.trim();
    if (s.isEmpty) return s;

    final rules = <(RegExp, String)>[
      (RegExp(r'^carrera\s+', caseSensitive: false), 'Cra. '),
      (RegExp(r'^calle\s+', caseSensitive: false), 'Cl. '),
      (RegExp(r'^avenida\s+', caseSensitive: false), 'Av. '),
      (RegExp(r'^diagonal\s+', caseSensitive: false), 'Diag. '),
      (RegExp(r'^transversal\s+', caseSensitive: false), 'Trans. '),
      (RegExp(r'^kr\.?\s+', caseSensitive: false), 'Cra. '),
      (RegExp(r'^cl\.?\s+', caseSensitive: false), 'Cl. '),
    ];
    for (final rule in rules) {
      if (rule.$1.hasMatch(s)) {
        s = s.replaceFirst(rule.$1, rule.$2);
        break;
      }
    }
    return s;
  }

  /// Calle del resultado de geocode más cercano al GPS (no la vía vecina del texto).
  /// Calle del **punto GPS**, no de la vía cuyo centroide queda más cerca.
  ///
  /// Google ordena `results` por relevancia a ese lat/lng. Si se elige la
  /// geometría más cercana, el chip salta a otra calle (p. ej. Cl. 15) aunque
  /// el teléfono esté en la cuadra de al lado.
  static const double _maxStreetSnapMeters = 80;

  String? _extractStreetFromNearestGeocodeResult(
    List<Map<String, dynamic>> results, {
    required double lat,
    required double lng,
  }) {
    String? fallback;

    for (final result in results) {
      final types = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (types.length == 1 && types.contains('plus_code')) continue;

      final components = result['address_components'] as List<dynamic>? ?? [];
      final route = _firstComponentValue(
        components,
        acceptedTypes: const ['route'],
      );
      if (route == null || route.trim().isEmpty) continue;

      final number = _firstComponentValue(
        components,
        acceptedTypes: const ['street_number'],
      );
      final line = _formatStreetLine(route, number);
      if (line == null || line.trim().isEmpty) continue;
      fallback ??= line;

      final meters = _geocodeResultRawMeters(result, lat: lat, lng: lng);
      if (meters.isFinite && meters <= _maxStreetSnapMeters) {
        return line;
      }
    }

    return fallback;
  }

  double _geocodeResultRawMeters(
    Map<String, dynamic> result, {
    required double lat,
    required double lng,
  }) {
    final geo = result['geometry'];
    if (geo is! Map) return double.infinity;
    final loc = geo['location'];
    if (loc is! Map) return double.infinity;
    final rLat = (loc['lat'] as num?)?.toDouble();
    final rLng = (loc['lng'] as num?)?.toDouble();
    if (rLat == null || rLng == null) return double.infinity;
    return Geolocator.distanceBetween(lat, lng, rLat, rLng);
  }

  double _geocodeResultProximityScore(
    Map<String, dynamic> result, {
    required double lat,
    required double lng,
  }) {
    final geo = result['geometry'];
    if (geo is! Map) return double.infinity;
    final loc = geo['location'];
    if (loc is! Map) return double.infinity;
    final rLat = (loc['lat'] as num?)?.toDouble();
    final rLng = (loc['lng'] as num?)?.toDouble();
    if (rLat == null || rLng == null) return double.infinity;

    var meters = Geolocator.distanceBetween(lat, lng, rLat, rLng);
    final locationType = geo['location_type']?.toString().toUpperCase() ?? '';
    switch (locationType) {
      case 'ROOFTOP':
        meters *= 0.55;
      case 'RANGE_INTERPOLATED':
        meters *= 0.72;
      case 'GEOMETRIC_CENTER':
        meters *= 1.35;
      case 'APPROXIMATE':
        meters *= 1.6;
    }

    final types = (result['types'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    if (types.contains('street_address')) meters *= 0.65;
    if (types.contains('premise') || types.contains('subpremise')) {
      meters *= 0.85;
    }
    return meters;
  }

  void _collectZonaConductorBarrioCandidates(
    List<Map<String, dynamic>> results,
    Set<String> out,
  ) {
    _collectZonaConductorCandidates(
      results,
      out,
      includeRoutes: false,
      includeFormattedParts: false,
    );
  }

  void _collectZonaConductorCandidates(
    List<Map<String, dynamic>> results,
    Set<String> out, {
    bool includeRoutes = true,
    bool includeFormattedParts = true,
  }) {
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

        if (includeRoutes && types.contains('route')) {
          addCandidate(component['long_name']?.toString());
          addCandidate(component['short_name']?.toString());
        }

        if (types.contains('locality') || types.contains('postal_town')) {
          addCandidate(component['long_name']?.toString());
          addCandidate(component['short_name']?.toString());
        }
      }

      if (includeFormattedParts) {
        final formatted = result['formatted_address']?.toString();
        if (formatted != null && formatted.isNotEmpty) {
          for (final part in formatted.split(',')) {
            addCandidate(part.trim());
          }
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

  /// Etiqueta para destino elegido tocando el mapa (sin Places nearby).
  Future<MapDestinationLabel> resolveMapDestinationLabel({
    required double lat,
    required double lng,
  }) async {
    const fallback = MapDestinationLabel(
      name: 'Destino en mapa',
      address: 'Ubicación seleccionada',
    );

    if (MapsConfig.useBackendProxy) {
      final r = await _taxiMaps.reverseGeocode(lat, lng);
      if (r != null && _proxyResultIsAligned(lat, lng, r)) {
        final addr = r.address?.trim() ?? '';
        final barrio = PlacePrecision.normalizeNeighborhood(r.barrio);
        final street = addr.isNotEmpty ? addr.split(',').first.trim() : '';
        final name = street.isNotEmpty
            ? street
            : (barrio.isNotEmpty ? barrio : fallback.name);
        return MapDestinationLabel(
          name: name,
          address: addr.isNotEmpty ? addr : name,
          area: barrio.isEmpty ? null : barrio,
        );
      }
      // Sin respuesta o sector desalineado: se intenta con Google más abajo.
    }

    final results = await _fetchGeocodeResults(lat: lat, lng: lng);
    if (results == null || results.isEmpty) return fallback;

    for (final result in results) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (resultTypes.length == 1 && resultTypes.contains('plus_code')) {
        continue;
      }
      final isPoi = resultTypes.contains('establishment') ||
          resultTypes.contains('point_of_interest') ||
          resultTypes.contains('shopping_mall') ||
          resultTypes.contains('store');
      if (!isPoi) continue;

      final formatted = _stripPlusCodes(
        result['formatted_address']?.toString() ?? '',
      );
      if (formatted.isEmpty) continue;
      final name = formatted.split(',').first.trim();
      if (name.isNotEmpty) {
        return MapDestinationLabel(name: name, address: formatted);
      }
    }

    final streetLine = _extractStreetLineFromResults(results, lat: lat, lng: lng);
    final fullAddress = _fullAddressFor(results, lat: lat, lng: lng) ?? '';
    final cleaned = _stripPlusCodes(fullAddress);
    var area = _extractAreaFromResults(results, lat: lat, lng: lng);
    area ??= await resolveAreaName(lat: lat, lng: lng);

    if (streetLine != null && streetLine.trim().isNotEmpty) {
      return MapDestinationLabel(
        name: streetLine.trim(),
        address: cleaned.isNotEmpty ? cleaned : streetLine.trim(),
        area: area,
      );
    }

    if (area != null && area.trim().isNotEmpty) {
      return MapDestinationLabel(
        name: area.trim(),
        address: cleaned.isNotEmpty ? cleaned : area.trim(),
        area: area,
      );
    }

    if (cleaned.isNotEmpty) {
      return MapDestinationLabel(
        name: placeNameFromAddressForDriver(cleaned),
        address: cleaned,
      );
    }

    return fallback;
  }

  /// Dirección formateada para un punto (ej. destino final al cerrar viaje).
  Future<String?> resolveFormattedAddress({
    required double lat,
    required double lng,
  }) async {
    if (MapsConfig.useBackendProxy) {
      final r = await _taxiMaps.reverseGeocode(lat, lng);
      return r?.address?.trim();
    }

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

  /// Etiqueta para conductor: calle/número primero; barrio como contexto.
  Future<CurrentLocationData> resolveDriverPickupLabel({
    required double lat,
    required double lng,
  }) async {
    const fallback = CurrentLocationData(
      name: 'Punto de recogida',
      address: 'Ubicación en mapa',
    );

    if (MapsConfig.useBackendProxy) {
      final cacheKey =
          'driver|${GeocodeMemoryCache.gridKey(lat, lng, decimals: 3)}';
      final cached = _getCachedLocationData(cacheKey);
      if (cached != null) return cached;
      final data = await _locationDataFromBackend(
        lat,
        lng,
        fallback: fallback,
        preferStreet: true,
      );
      if (data != null) {
        _putCachedLocationData(cacheKey, data);
        return data;
      }
      // Proxy desalineado/sin dato: se intenta con Google más abajo.
    }

    final cacheKey =
        'driver|${GeocodeMemoryCache.gridKey(lat, lng, decimals: 3)}';
    final cached = _getCachedLocationData(cacheKey);
    if (cached != null) return cached;

    var results = await _fetchGeocodeResults(
      lat: lat,
      lng: lng,
      resultType: 'street_address|premise|subpremise|route',
      logLabel: 'driver_street',
    );
    results ??= await _fetchGeocodeResults(lat: lat, lng: lng);
    if (results == null || results.isEmpty) return fallback;

    final streetLine = _extractStreetLineFromResults(results, lat: lat, lng: lng);
    final fullAddress = _fullAddressFor(results, lat: lat, lng: lng);
    var area = _extractAreaFromResults(results, lat: lat, lng: lng);
    area ??= _areaFromCachedFetch(lat, lng);

    final name = (streetLine != null && streetLine.trim().isNotEmpty)
        ? streetLine.trim()
        : (fullAddress != null && fullAddress.isNotEmpty
            ? placeNameFromAddressForDriver(fullAddress)
            : (area ?? fallback.name));

    final data = CurrentLocationData(
      name: name,
      address: fullAddress?.trim().isNotEmpty == true
          ? fullAddress!.trim()
          : name,
      area: area,
      streetLine: streetLine,
    );
    _putCachedLocationData(cacheKey, data);
    return data;
  }

  static String placeNameFromAddressForDriver(String value) {
    final parts = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return value.trim();
    if (list.length >= 2 &&
        RegExp(r'\d').hasMatch(list.first) &&
        list.first.length < 40) {
      return list.first;
    }
    return list.first;
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

    if (MapsConfig.useBackendProxy) {
      final cacheKey =
          'label|${GeocodeMemoryCache.gridKey(lat, lng, decimals: 3)}';
      final cached = _getCachedLocationData(cacheKey);
      if (cached != null) return cached;
      final data = await _locationDataFromBackend(lat, lng, fallback: fallback);
      if (data != null) {
        _putCachedLocationData(cacheKey, data);
        return data;
      }
      // Proxy desalineado/sin dato: se intenta con Google más abajo.
    }

    final cacheKey =
        'label|${GeocodeMemoryCache.gridKey(lat, lng, decimals: 3)}';
    final cached = _getCachedLocationData(cacheKey);
    if (cached != null) return cached;

    final results = await _fetchGeocodeResults(lat: lat, lng: lng);
    if (results == null || results.isEmpty) return fallback;

    var area = _extractAreaFromResults(results, lat: lat, lng: lng);
    if (area == null) {
      final neighborhoodResults = await _fetchGeocodeResults(
        lat: lat,
        lng: lng,
        resultType:
            'neighborhood|sublocality|sublocality_level_1|sublocality_level_2|sublocality_level_3|administrative_area_level_3',
        logLabel: 'neighborhood',
      );
      if (neighborhoodResults != null && neighborhoodResults.isNotEmpty) {
        area = _extractAreaFromResults(
          neighborhoodResults,
          lat: lat,
          lng: lng,
        );
      }
    }

    final streetLine = _extractStreetLineFromResults(results, lat: lat, lng: lng);
    final fullAddress = _fullAddressFor(results, lat: lat, lng: lng);

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

    final data = CurrentLocationData(
      name: displayName,
      address: fullAddress ?? displayName,
      area: area,
      streetLine: streetLine,
    );
    _putCachedLocationData(cacheKey, data);
    return data;
  }

  Future<CurrentLocationData?> _locationDataFromBackend(
    double lat,
    double lng, {
    required CurrentLocationData fallback,
    bool preferStreet = false,
  }) async {
    final r = await _taxiMaps.reverseGeocode(lat, lng);
    // Sin respuesta o sector desalineado con el punto consultado: que decida
    // Google (el caller conserva el proxy como respaldo si Google falla).
    if (r == null || !_proxyResultIsAligned(lat, lng, r)) return null;

    final addr = r.address?.trim() ?? '';
    final barrio = PlacePrecision.normalizeNeighborhood(r.barrio);
    final zona = r.zona?.trim();
    final street = addr.isNotEmpty ? addr.split(',').first.trim() : '';
    // En zonas sin calle mapeada la dirección arranca con el barrio
    // ("Los Alamos de Occidente, Popayán, ..."). Eso no es una calle: si se
    // tomara como tal, el conductor vería el barrio disfrazado de dirección.
    final streetIsStreet = street.isNotEmpty && _looksLikeStreetName(street);

    String name;
    if (zona != null && zona.isNotEmpty) {
      name = zona;
    } else if (preferStreet && streetIsStreet) {
      name = street;
    } else if (barrio.isNotEmpty && !preferStreet) {
      name = barrio;
    } else if (streetIsStreet) {
      name = street;
    } else if (barrio.isNotEmpty) {
      name = barrio;
    } else if (addr.isNotEmpty) {
      name = placeNameFromAddressForDriver(addr);
    } else {
      name = fallback.name;
    }

    return CurrentLocationData(
      name: name,
      address: addr.isNotEmpty ? addr : name,
      area: barrio.isEmpty ? null : barrio,
      streetLine: streetIsStreet ? street : null,
    );
  }

  String? _areaFromCachedFetch(double lat, double lng) {
    final fetchKey =
        'fetch|${GeocodeMemoryCache.gridKey(lat, lng)}||default';
    final cached = _cache.get<List<Map<String, dynamic>>>(fetchKey);
    if (cached == null) return null;
    return _extractAreaFromResults(cached, lat: lat, lng: lng);
  }

  CurrentLocationData? _getCachedLocationData(String key) {
    final raw = _cache.get<Map<String, dynamic>>(key);
    if (raw == null) return null;
    return CurrentLocationData(
      name: raw['name']?.toString() ?? '',
      address: raw['address']?.toString() ?? '',
      area: raw['area']?.toString(),
      streetLine: raw['streetLine']?.toString(),
    );
  }

  void _putCachedLocationData(String key, CurrentLocationData data) {
    _cache.put<Map<String, dynamic>>(
      key,
      {
        'name': data.name,
        'address': data.address,
        'area': data.area,
        'streetLine': data.streetLine,
      },
      _labelCacheTtl,
    );
  }

  Future<List<Map<String, dynamic>>?> _fetchGeocodeResults({
    required double lat,
    required double lng,
    String? resultType,
    String logLabel = 'default',
  }) async {
    final cacheKey =
        'fetch|${GeocodeMemoryCache.gridKey(lat, lng)}|${resultType ?? ''}|$logLabel';
    final cached = _cache.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

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

      if (results.isNotEmpty) {
        _cache.put(cacheKey, results, _fetchCacheTtl);
      }
      return results;
    } catch (e) {
      AppLogger.d('⚠️ Error en geocode reverso: $e');
      return null;
    }
  }

  /// Extrae el barrio de los resultados de geocode.
  ///
  /// Google en Popayán devuelve el barrio real como `neighborhood`
  /// ("Ciudad Jardín", "Barrio Pandiguando") y la zona como
  /// `sublocality_level_1` ("Centro", "Santa Teresa"). Se prioriza el
  /// componente más específico y se descartan las etiquetas de zona:
  /// es preferible sin barrio antes que con el barrio equivocado.
  String? _extractAreaFromResults(
    List<Map<String, dynamic>> results, {
    double? lat,
    double? lng,
  }) {
    final ordered = _orderByProximity(results, lat: lat, lng: lng);

    // 1) Barrio real (`neighborhood`) del resultado más cercano.
    for (final result in ordered) {
      final value = _bestNeighborhoodComponent(result, preferSpecific: true);
      if (value != null && _isValidBarrioCandidate(value)) {
        return PlacePrecision.normalizeNeighborhood(value);
      }
    }

    // 2) Cualquier tipo de barrio (`sublocality_level_*`) del más cercano.
    for (final result in ordered) {
      final value = _bestNeighborhoodComponent(result, preferSpecific: false);
      if (value != null && _isValidBarrioCandidate(value)) {
        return PlacePrecision.normalizeNeighborhood(value);
      }
    }

    // 3) Resultado filtrado por result_type=neighborhood: formatted_address.
    for (final result in ordered) {
      final resultTypes = (result['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (!resultTypes.any(_barrioTypes.contains)) continue;
      final formatted = result['formatted_address']?.toString();
      if (_isValidBarrioCandidate(formatted)) {
        return PlacePrecision.normalizeNeighborhood(
          formatted!.split(',').first.trim(),
        );
      }
    }

    return null;
  }

  /// Ordena los resultados por cercanía real al punto consultado.
  ///
  /// Google mezcla barrios de localidades vecinas en el mismo listado.
  List<Map<String, dynamic>> _orderByProximity(
    List<Map<String, dynamic>> results, {
    double? lat,
    double? lng,
  }) {
    if (lat == null || lng == null || results.length < 2) return results;
    final ranked = <MapEntry<double, Map<String, dynamic>>>[
      for (final r in results)
        MapEntry(_geocodeResultProximityScore(r, lat: lat, lng: lng), r),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return ranked.map((e) => e.value).toList();
  }

  /// ¿El punto consultado está sobre una calle realmente mapeada?
  ///
  /// Google inventa direcciones (calle + número) donde no hay cobertura y
  /// las marca como `ROOFTOP`. Si el resultado más cercano no trae `route`,
  /// ninguna de esas direcciones sirve: se muestra el barrio.
  bool _puntoTieneCalleReal(
    List<Map<String, dynamic>> results, {
    double? lat,
    double? lng,
  }) {
    if (results.isEmpty) return false;
    return PlacePrecision.hasMappedStreet(
      _orderByProximity(results, lat: lat, lng: lng),
    );
  }

  /// Dirección formateada del punto, o `null` si no hay una real.
  ///
  /// Google sintetiza direcciones en zonas sin cobertura y las marca como
  /// `ROOFTOP` ("Cl. 15 # 37-222" en Los Alamos de Occidente). Cuando el
  /// punto no está sobre una calle mapeada, esas direcciones no sirven:
  /// se devuelve `null` y el barrio queda como referencia.
  String? _fullAddressFor(
    List<Map<String, dynamic>> results, {
    double? lat,
    double? lng,
  }) {
    final extracted = _extractFormattedAddress(results, lat: lat, lng: lng);
    if (extracted != null) return extracted;
    if (!_puntoTieneCalleReal(results, lat: lat, lng: lng)) return null;
    return results.first['formatted_address']?.toString();
  }

  /// Tipos de componente que pueden contener un barrio.
  static const List<String> _barrioTypes = [
    'neighborhood',
    'sublocality',
    'sublocality_level_1',
    'sublocality_level_2',
    'sublocality_level_3',
    'administrative_area_level_3',
  ];

  /// Peso de especificidad: mientras más alto, más granular es el barrio.
  static const Map<String, int> _barrioSpecificity = {
    'neighborhood': 60,
    'sublocality_level_3': 50,
    'sublocality_level_2': 40,
    'sublocality_level_1': 30,
    'sublocality': 20,
    'administrative_area_level_3': 10,
  };

  /// Mejor componente de barrio de un resultado de geocode.
  ///
  /// Con [preferSpecific] solo acepta `neighborhood` (el barrio real);
  /// sin él, acepta cualquier nivel de sublocalidad.
  String? _bestNeighborhoodComponent(
    Map<String, dynamic> result, {
    required bool preferSpecific,
  }) {
    final resultTypes = (result['types'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    if (resultTypes.contains('plus_code') ||
        resultTypes.contains('postal_code')) {
      return null;
    }

    final components = result['address_components'] as List<dynamic>? ?? [];
    String? best;
    var bestScore = -1;
    for (final item in components) {
      final component = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      final types = (component['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      var score = 0;
      for (final type in types) {
        final weight = _barrioSpecificity[type];
        if (weight == null) continue;
        if (preferSpecific && type != 'neighborhood') continue;
        if (weight > score) score = weight;
      }
      if (score <= 0) continue;

      final value =
          component['long_name']?.toString() ??
          component['short_name']?.toString();
      if (value == null || value.trim().isEmpty) continue;
      if (score > bestScore) {
        bestScore = score;
        best = value.trim();
      }
    }
    return best;
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

  String? _extractStreetLineFromResults(
    List<Map<String, dynamic>> results, {
    double? lat,
    double? lng,
  }) {
    // Sin calle realmente mapeada, Google inventa la dirección: mejor el
    // barrio que un "Cl. 15 # 37-222" que no existe.
    if (!_puntoTieneCalleReal(results, lat: lat, lng: lng)) return null;

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

  String? _extractFormattedAddress(
    List<Map<String, dynamic>> results, {
    double? lat,
    double? lng,
  }) {
    // Dirección inventada por Google en zonas sin calle mapeada: no sirve.
    if (!_puntoTieneCalleReal(results, lat: lat, lng: lng)) return null;

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
    // "Centro", "Comuna 4", "Perímetro Urbano Popayán" son zonas, no barrios.
    if (!PlacePrecision.isPlausibleNeighborhood(v)) return false;
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
    // Formas abreviadas que devuelve el backend: "Cra. 5", "Cl. 2", "Av 6N",
    // "Tv. 20", "Kra 12". Sin "cra"/"kra"/"tv" estas NO se detectaban y el
    // barrio terminaba reemplazando a la calle.
    return RegExp(
      r'^(calle|carrera|cra|cr|cl|cll|avenida|av|diag|diagonal|trans|transversal|tv|km|kra|kr|via|vía|carretera)(?![a-záéíóúüñ])',
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

  static const bool _verboseGeocodeLogs = false;

  void _logGeocodeRawResponse({
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> results,
  }) {
    if (!kDebugMode || !_verboseGeocodeLogs) return;
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

class MapDestinationLabel {
  final String name;
  final String address;
  final String? area;

  const MapDestinationLabel({
    required this.name,
    required this.address,
    this.area,
  });
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

  /// Título en tarjeta del conductor (calle o dirección, no solo barrio).
  String get driverTitle {
    final calle = streetLine?.trim();
    if (calle != null && calle.isNotEmpty) return calle;
    if (name.trim().isNotEmpty && name != 'Mi ubicación') return name;
    return address.trim().isNotEmpty ? address : 'Punto de recogida';
  }

  /// Segunda línea: barrio + dirección completa.
  String get driverSubtitle {
    final barrio = area?.trim();
    final parts = <String>[];
    if (barrio != null &&
        barrio.isNotEmpty &&
        !driverTitle.toLowerCase().contains(barrio.toLowerCase())) {
      parts.add(barrio);
    }
    if (address.trim().isNotEmpty &&
        address.trim().toLowerCase() != driverTitle.trim().toLowerCase()) {
      parts.add(address.trim());
    }
    return parts.join(' · ');
  }
}