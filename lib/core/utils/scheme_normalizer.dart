class SchemeNormalizer {
  const SchemeNormalizer._();

  static const anyScheme = 'Any Programme';

  static List<String> availableSchemes(Iterable<String?> rawSchemes) {
    final schemes = <String>{};
    for (final rawScheme in rawSchemes) {
      final normalized = normalize(rawScheme);
      if (normalized.isNotEmpty) {
        schemes.add(normalized);
      }
    }
    return [anyScheme, ...schemes.toList()..sort()];
  }

  static String normalize(String? value) {
    final raw = _clean(value);
    if (raw.isEmpty) {
      return '';
    }
    final searchable = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (searchable == 'ppam' || searchable.contains('penjawat awam')) {
      return 'PPAM';
    }
    if (searchable.contains('pr1ma') || searchable.contains('1malaysia')) {
      return 'PR1MA Homes';
    }
    if (searchable == 'spnb' ||
        searchable.contains('syarikat perumahan negara')) {
      return 'SPNB';
    }
    if (searchable == 'ppr' ||
        searchable.contains('program perumahan rakyat')) {
      return 'PPR';
    }
    if (searchable.contains('residensi wilayah') ||
        searchable.contains('rumawip')) {
      return 'Residensi Wilayah';
    }
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool matches(String? propertyScheme, String? selectedScheme) {
    final selected = _clean(selectedScheme);
    if (selected.isEmpty ||
        selected == 'Any' ||
        selected == anyScheme ||
        selected == 'Any Scheme') {
      return true;
    }
    return normalize(propertyScheme) == normalize(selected);
  }

  static String _clean(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
