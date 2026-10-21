import 'dart:math' as math;

/// Lógica de precisión para nombres de barrio/zona y para ordenar resultados
/// de búsqueda por cercanía real al usuario.
///
/// Contexto (verificado contra Nominatim y Google Geocoding):
/// - En Popayán el barrio real vive en `neighbourhood` de Nominatim
///   (Pandiguando, Moscopán, El Cadillal, Tunel Bajo, Ciudad Jardín...).
/// - Google suele devolver la *zona* (`Centro`, `Comuna 1`, `Santa Teresa`)
///   o directamente nada. Por eso el barrio nunca debe salir de Google sin
///   validar: es mejor quedarse sin barrio que mostrar el de otra zona.
abstract final class PlacePrecision {
  /// Contexto geográfico que se anexa a las búsquedas para que el
  /// geocoder no resuelva en Bogotá/Cali/Medellín.
  static const String areaContext = 'Popayán, Cauca, Colombia';

  /// Etiquetas que son sector amplio, no barrio.
  static const Set<String> _zoneLabels = {
    'centro',
    'perimetro urbano popayan',
    'perimetro urbano de popayan',
    'popayan',
    'cauca',
    'colombia',
    'rap pacifico',
    'america del sur',
    'norte',
    'sur',
    'este',
    'oeste',
  };

  static final RegExp _comunaRegex = RegExp(
    r'^comuna\s*\d+\s*$',
    caseSensitive: false,
  );

  static final RegExp _streetRegex = RegExp(
    r'^(calle|carrera|cra|cr|cl|avenida|av|diag|diagonal|trans|transversal|km|via|vía|carretera|route)(?![a-záéíóúüñ])',
    caseSensitive: false,
  );

  static final RegExp _plusCodeRegex = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}$',
    caseSensitive: false,
  );

  /// Calle/carrera al estilo inDrive (`Cl. 15`, `Cra. 20b`).
  static bool looksLikeStreetLabel(String? value) {
    if (value == null) return false;
    final first = value.trim().split(',').first.trim();
    if (first.isEmpty || isPlusCodeLabel(first)) return false;
    return _streetRegex.hasMatch(first);
  }

  /// Google a veces pone el Plus Code (`C9X6+JV`) como “dirección”.
  static bool isPlusCodeLabel(String? value) {
    if (value == null) return false;
    final first = value.trim().split(',').first.trim();
    if (first.isEmpty) return false;
    return _plusCodeRegex.hasMatch(first);
  }

  /// Calle/carrera numerada con # que Google inventa en zonas sin nomenclatura
  /// (ej. `Cl. 15 # 37-222` cuando el mapa dice Aguas Vivas).
  static bool looksLikeInventedGridStreet(String? value) {
    if (value == null) return false;
    final first = value.trim().split(',').first.trim();
    if (first.isEmpty || isPlusCodeLabel(first)) return false;
    final numbered = RegExp(
      r'^(cl\.?|calle|cra\.?|cr\.?|carrera|diag\.?|dg\.?|diagonal|trans\.?|tv\.?|transversal)\s*\d',
      caseSensitive: false,
    );
    if (!numbered.hasMatch(first)) return false;
    return first.contains('#') || RegExp(r'\d+\s*-\s*\d+').hasMatch(first);
  }

  static final RegExp _onlyDigits = RegExp(r'^\d+$');

  /// Números de casa, rangos y códigos postales ("9-27", "190003", "12 # 4").
  static final RegExp _numberLike = RegExp(r'^[\d\s\-/#]+$');

  /// Palabras que ya anclan la búsqueda a la zona y no deben duplicarse.
  static final RegExp _hasAreaAnchor = RegExp(
    r'(popay[aá]n|cauca|colombia|timbi[oó]|silvia|quilichao|piendam[oó]|cerezo|puerto tejada)',
    caseSensitive: false,
  );

  /// ¿El texto es un barrio utilizable (ni sector amplio, ni vía, ni código)?
  ///
  /// Un barrio de verdad: "Pandiguando", "Moscopán", "Ciudad Jardín".
  /// No lo son: "Centro", "Comuna 4", "Perímetro Urbano Popayán", "Popayán".
  static bool isPlausibleNeighborhood(String? value) {
    final v = _normalizeKey(value);
    if (v.length < 3) return false;
    if (_plusCodeRegex.hasMatch(v)) return false;
    if (_onlyDigits.hasMatch(v)) return false;
    if (_numberLike.hasMatch(v)) return false;
    if (_comunaRegex.hasMatch(v)) return false;
    if (_zoneLabels.contains(v)) return false;
    if (_streetRegex.hasMatch(v)) return false;
    return true;
  }

  /// Etiqueta de zona (sector) válida pero poco precisa: "Centro".
  ///
  /// Solo se usa cuando no hay ninguna fuente de barrio mejor.
  static bool isPlausibleZoneLabel(String? value) {
    final v = _normalizeKey(value);
    if (v.length < 3) return false;
    if (_plusCodeRegex.hasMatch(v)) return false;
    if (_onlyDigits.hasMatch(v)) return false;
    if (_numberLike.hasMatch(v)) return false;
    if (_comunaRegex.hasMatch(v)) return false;
    if (_streetRegex.hasMatch(v)) return false;
    return _zoneLabels.contains(v);
  }

  /// Normaliza el texto de barrio para mostrarlo:
  /// "Barrio solidaridad" → "Solidaridad" · "ciudad jardin" → "Ciudad jardin".
  ///
  /// Solo se corrige la mayúscula inicial: el resto del texto se respeta
  /// tal como viene de la fuente. Capitalizar cada palabra convertiría
  /// "Los Alamos de Occidente" en "Los Alamos De Occidente".
  static String normalizeNeighborhood(String? value) {
    if (value == null) return '';
    var v = value.trim();
    if (v.isEmpty) return '';

    // Quita prefijos redundantes ("Barrio X" → "X").
    v = v.replaceFirst(RegExp(r'^barrios?\s+', caseSensitive: false), '');

    // "Barrio" suelto no aporta nada.
    if (v.trim().toLowerCase() == 'barrio') return '';

    // Espacios repetidos.
    v = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (v.isEmpty) return '';

    return _capitalizeFirst(v);
  }

  static String _capitalizeFirst(String word) {
    if (word.isEmpty) return word;
    final first = word[0];
    final upper = first.toUpperCase();
    if (first == upper) return word;
    return '$upper${word.substring(1)}';
  }

  /// Añade el contexto de Popayán a la consulta si el usuario no lo puso.
  ///
  /// Sin esto Nominatim resuelve "carrera 5" en Bogotá y "cafeteria" en
  /// Medellín; con esto la misma consulta trae resultados locales.
  static String withAreaContext(String query) {
    final q = query.trim();
    if (q.isEmpty) return '';
    if (_hasAreaAnchor.hasMatch(q)) return q;
    return '$q, $areaContext';
  }

  /// Distancia en metros entre dos puntos (haversine).
  ///
  /// Devuelve infinito si algún coordenada no es válida, para que el
  /// ordenamiento de resultados sin coordenadas quede al final.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    if (!lat1.isFinite || !lng1.isFinite || !lat2.isFinite || !lng2.isFinite) {
      return double.infinity;
    }
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  /// Ordena por cercanía al origen, conservando el orden original entre
  /// empates (estable) para no cambiar la preferencia del geocoder.
  static List<T> sortByProximity<T>(
    List<T> items, {
    required double? originLat,
    required double? originLng,
    required double Function(T item) latOf,
    required double Function(T item) lngOf,
  }) {
    if (originLat == null || originLng == null) return items;
    if (items.length < 2) return items;

    final indexed = <({int index, T item, double distance})>[];
    for (var i = 0; i < items.length; i++) {
      indexed.add((
        index: i,
        item: items[i],
        distance: distanceMeters(
          originLat,
          originLng,
          latOf(items[i]),
          lngOf(items[i]),
        ),
      ));
    }
    indexed.sort((a, b) {
      final byDistance = a.distance.compareTo(b.distance);
      return byDistance != 0 ? byDistance : a.index.compareTo(b.index);
    });
    return indexed.map((e) => e.item).toList();
  }

  /// Quita duplicados por proximity: dos entradas a menos de [minMeters]
  /// entre sí (y con el mismo nombre) se consideran la misma.
  static List<T> dedupeByProximity<T>(
    List<T> items, {
    required double Function(T item) latOf,
    required double Function(T item) lngOf,
    required String Function(T item) keyOf,
    double minMeters = 35,
  }) {
    final out = <T>[];
    for (final item in items) {
      final key = keyOf(item).toLowerCase().trim();
      final lat = latOf(item);
      final lng = lngOf(item);
      var duplicate = false;
      for (final kept in out) {
        if (keyOf(kept).toLowerCase().trim() != key) continue;
        if (distanceMeters(lat, lng, latOf(kept), lngOf(kept)) <= minMeters) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) out.add(item);
    }
    return out;
  }

  /// Texto corto de distancia para la UI ("A 250 m", "1,4 km").
  static String formatDistance(double meters) {
    if (!meters.isFinite || meters < 0) return '';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    final text = km.toStringAsFixed(1).replaceAll('.', ',');
    return '$text km';
  }

  /// ¿El punto está sobre una calle realmente mapeada?
  ///
  /// Google **sintetiza** direcciones donde no hay cobertura: devuelve tres
  /// `street_address` distintos, todos marcados `ROOFTOP`, y el primero es un
  /// `plus_code`. Ejemplo real en Popayán (Los Alamos de Occidente):
  ///   [0] C9X6+JV, Popayán            ← sin `route`: aquí no hay calle
  ///   [1] Cl. 15 # 37-222, Popayán     ← inventada
  ///   [2] Cra. 41 # 18-27, Popayán     ← inventada
  ///
  /// Si el resultado más cercano no trae componente `route`, ninguna de esas
  /// direcciones es real y hay que mostrar el barrio en su lugar.
  static bool hasMappedStreet(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return false;
    final closest = results.first;
    final components = closest['address_components'];
    if (components is! List) return false;
    for (final item in components) {
      final component = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      final types = component['types'];
      if (types is! List) continue;
      if (types.any((t) => t.toString() == 'route')) return true;
    }
    return false;
  }

  /// Normaliza para comparar: minúsculas, sin acentos y sin espacios de más.
  ///
  /// Sin quitar acentos, «Perímetro Urbano Popayán» no coincidía con la
  /// lista de zonas y se colaba como si fuera un barrio.
  static String _normalizeKey(String? value) {
    final raw = (value ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return raw
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  static double _toRad(double degrees) => degrees * (math.pi / 180);
}
