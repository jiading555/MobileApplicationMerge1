import '../../models/property.dart';
import 'location_normalizer.dart';
import 'property_type_normalizer.dart';
import 'scheme_normalizer.dart';

class PropertyFilterNormalizer {
  static String normalizeAreaId(String? value) {
    return LocationNormalizer.canonicalAreaIdFromExisting(value);
  }

  static bool areaMatches(String? propertyAreaId, String? selectedAreaId) {
    if (selectedAreaId == null ||
        selectedAreaId.trim().isEmpty ||
        selectedAreaId == 'Any') {
      return true;
    }
    return normalizeAreaId(propertyAreaId) == normalizeAreaId(selectedAreaId);
  }

  static bool stateMatches(String? propertyState, String? selectedState) {
    if (selectedState == null ||
        selectedState.trim().isEmpty ||
        selectedState == 'Any') {
      return true;
    }
    return LocationNormalizer.stateMatches(propertyState, selectedState);
  }

  static String normalizeType(String? value) {
    return PropertyTypeNormalizer.normalize(value);
  }

  static bool typeMatches(String? propertyType, String? selectedType) {
    return PropertyTypeNormalizer.matches(propertyType, selectedType);
  }

  static bool propertyTypeMatches(Property property, String? selectedType) {
    final candidates = _propertyTypeCandidates(property);
    if (candidates.isEmpty) {
      return PropertyTypeNormalizer.matches(null, selectedType);
    }
    return candidates.any(
      (type) => PropertyTypeNormalizer.matches(type, selectedType),
    );
  }

  static List<String> availableTypes(Iterable<String?> propertyTypes) {
    return PropertyTypeNormalizer.availableCategories(propertyTypes);
  }

  static List<String> availablePropertyTypes(Iterable<Property> properties) {
    return PropertyTypeNormalizer.availableCategories(
      properties.expand(_propertyTypeCandidates),
    );
  }

  static String normalizeScheme(String? value) {
    return SchemeNormalizer.normalize(value);
  }

  static bool schemeMatches(String? propertyScheme, String? selectedScheme) {
    return SchemeNormalizer.matches(propertyScheme, selectedScheme);
  }

  static List<String> availableSchemes(Iterable<String?> propertySchemes) {
    return SchemeNormalizer.availableSchemes(propertySchemes);
  }

  static String normalizeTenure(String? value) {
    final raw = _clean(value);
    if (raw.isEmpty) {
      return 'Any';
    }
    final searchable = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final tenureMap = <String, String>{
      'freehold': 'Freehold',
      'free hold': 'Freehold',
      'bebas': 'Freehold',
      'pegangan bebas': 'Freehold',
      'leasehold': 'Leasehold',
      'lease hold': 'Leasehold',
      'lease': 'Leasehold',
      'pajakan': 'Leasehold',
      'pegangan pajakan': 'Leasehold',
    };
    return tenureMap[searchable] ?? _titleCase(searchable);
  }

  static bool tenureMatches(String? propertyTenure, String? selectedTenure) {
    if (selectedTenure == null ||
        selectedTenure.trim().isEmpty ||
        selectedTenure == 'Any') {
      return true;
    }
    return normalizeTenure(propertyTenure) == normalizeTenure(selectedTenure);
  }

  static bool matchPrice(Property property, int? maximumPrice) {
    if (maximumPrice == null) {
      return true;
    }
    final comparablePrice =
        property.price ?? property.priceMin ?? property.priceMax;
    if (comparablePrice == null) {
      return true;
    }
    return comparablePrice <= maximumPrice;
  }

  static String _clean(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static Iterable<String> _propertyTypeCandidates(Property property) {
    if (_clean(property.verifiedPropertyType).isNotEmpty) {
      return [property.verifiedPropertyType!];
    }
    final unitOptionTypes = property.unitOptions
        .map((option) => option.unitType)
        .where((type) => _clean(type).isNotEmpty)
        .cast<String>()
        .toList();
    if (unitOptionTypes.isNotEmpty) {
      return unitOptionTypes;
    }
    if (property.unitTypes.isNotEmpty) {
      return property.unitTypes;
    }
    final rawType = _clean(property.type).toLowerCase();
    if (property.isGovernmentRecord &&
        (rawType == 'public housing' || rawType == 'public')) {
      return const [];
    }
    return [property.type].where((type) => _clean(type).isNotEmpty);
  }

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value
        .split(RegExp(r'\s+'))
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
