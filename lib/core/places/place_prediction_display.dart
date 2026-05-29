/// Texto corto para predicciones Nominatim (autocomplete backend).
abstract final class PlacePredictionDisplay {
  static ({String mainText, String secondaryText, String description})
      formatBackend({
    String? name,
    String? address,
    String? description,
  }) {
    final full = _fullText(name: name, address: address, description: description);
    if (full.isEmpty) {
      return (mainText: '', secondaryText: '', description: '');
    }

    final parts = _meaningfulParts(full);
    if (parts.isEmpty) {
      final short = _truncate(full, 72);
      return (
        mainText: short,
        secondaryText: '',
        description: short,
      );
    }

    final main = parts.first;
    final secondary = parts.length > 1
        ? parts.sublist(1, parts.length > 3 ? 3 : parts.length).join(', ')
        : '';
    final shortSecondary = _truncate(secondary, 64);
    final shortDesc = shortSecondary.isEmpty
        ? main
        : '${main.trim()}, ${shortSecondary.trim()}';

    return (
      mainText: main,
      secondaryText: shortSecondary,
      description: shortDesc,
    );
  }

  static String _fullText({
    String? name,
    String? address,
    String? description,
  }) {
    final desc = description?.trim() ?? '';
    if (desc.isNotEmpty) return desc;
    final addr = address?.trim() ?? '';
    if (addr.isNotEmpty) return addr;
    return name?.trim() ?? '';
  }

  static List<String> _meaningfulParts(String full) {
    return full
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !_isNoisePart(e))
        .toList();
  }

  static bool _isNoisePart(String part) {
    final p = _norm(part);
    if (p.isEmpty) return true;
    if (RegExp(r'^\d{5,6}$').hasMatch(p)) return true;
    if (p.contains('perimetro urbano')) return true;
    if (p.contains('rap pacifico')) return true;
    if (p == 'popayan' || p.startsWith('popayan ')) return true;
    if (p == 'cauca' || p.endsWith(' cauca')) return true;
    if (p.contains('colombia')) return true;
    return false;
  }

  static String _norm(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  static String _truncate(String value, int maxLen) {
    final t = value.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1).trim()}…';
  }
}
