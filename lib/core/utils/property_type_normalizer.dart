class PropertyTypeNormalizer {
  const PropertyTypeNormalizer._();

  static const anyType = 'Any Type';
  static const apartmentFlat = 'Apartment / Flat';
  static const terraceHouse = 'Terrace House';
  static const semiDetached = 'Semi-Detached';
  static const bungalowDetached = 'Bungalow / Detached';
  static const townhouse = 'Townhouse';
  static const clusterHouse = 'Cluster House';
  static const shopApartment = 'Shop Apartment';
  static const other = 'Others';

  static const orderedCategories = [
    apartmentFlat,
    terraceHouse,
    semiDetached,
    bungalowDetached,
    townhouse,
    clusterHouse,
    shopApartment,
    other,
  ];

  static List<String> availableCategories(Iterable<String?> rawTypes) {
    final available = <String>{};
    for (final rawType in rawTypes) {
      available.addAll(categoriesFor(rawType));
    }
    return [anyType, ...orderedCategories.where(available.contains)];
  }

  static Set<String> categoriesFor(String? value) {
    final raw = _clean(value);
    if (raw.isEmpty) {
      return const {};
    }

    final categories = <String>{};
    for (final segment in _segments(raw)) {
      final category = _categoryForSegment(segment);
      if (category != null) {
        categories.add(category);
      }
    }

    if (categories.isEmpty) {
      categories.add(other);
    }
    return categories;
  }

  static String normalize(String? value) {
    final categories = categoriesFor(value);
    return categories.isEmpty ? anyType : categories.first;
  }

  static bool matches(String? rawType, String? selectedType) {
    final selected = _clean(selectedType);
    if (selected.isEmpty || selected == 'Any' || selected == anyType) {
      return true;
    }
    final selectedCategories = orderedCategories.contains(selected)
        ? {selected}
        : categoriesFor(selected);
    if (selectedCategories.isEmpty) {
      return false;
    }
    final propertyCategories = categoriesFor(rawType);
    return selectedCategories.any(propertyCategories.contains);
  }

  static List<String> _segments(String value) {
    return value
        .split(RegExp(r'[;,/|\\]+|\s+(?:dan|and)\s+', caseSensitive: false))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  static String? _categoryForSegment(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return null;
    }
    if (_containsAny(normalized, const [
      'semi d',
      'semi detached',
      'rumah berkembar',
      'berkembar',
    ])) {
      return semiDetached;
    }
    if (_containsAny(normalized, const [
      'pangsapuri',
      'apartmen',
      'apartment',
      'rumah pangsa',
      'flat',
      'kondominium',
      'condominium',
      'condo',
    ])) {
      return apartmentFlat;
    }
    if (_containsAny(normalized, const ['rumah teres', 'teres', 'terrace'])) {
      return terraceHouse;
    }
    if (_containsAny(normalized, const [
      'banglo',
      'bungalow',
      'rumah sesebuah',
      'sesebuah',
      'detached',
      'villa',
    ])) {
      return bungalowDetached;
    }
    if (_containsAny(normalized, const [
      'rumah bandar',
      'townhouse',
      'town house',
    ])) {
      return townhouse;
    }
    if (_containsAny(normalized, const [
      'rumah kluster',
      'kluster',
      'cluster',
    ])) {
      return clusterHouse;
    }
    if (_containsAny(normalized, const [
      'kedai pejabat',
      'pangsapuri kedai',
      'apartmen kedai',
      'shop apartment',
      'rumah kedai',
      'kedai',
      'pejabat',
      'shop office',
      'shop',
      'office',
    ])) {
      return shopApartment;
    }
    return null;
  }

  static bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }

  static String _clean(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
