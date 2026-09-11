import '../core/utils/property_type_normalizer.dart';

class Property {
  const Property({
    required this.id,
    required this.name,
    required this.areaId,
    required this.address,
    required this.type,
    required this.tenure,
    this.verifiedPropertyType,
    this.state,
    this.district,
    this.price,
    this.priceMin,
    this.priceMax,
    this.bedrooms,
    this.bathrooms,
    this.sizeSqft,
    this.latitude,
    this.longitude,
    required this.summary,
    required this.facilities,
    required this.palette,
    this.source = 'Local sample listing',
    this.sourceId,
    this.scheme,
    this.projectStatus,
    this.developerName,
    this.totalUnits,
    this.availableUnits,
    this.unitTypes = const [],
    this.unitOptions = const [],
    this.sourceUrl,
    this.externalProjectUrl,
    this.developerAddress,
    this.rawLocation,
    this.retrievedAt,
  });

  final String id;
  final String name;
  final String areaId;
  final String address;
  final String type;
  final String tenure;
  final String? verifiedPropertyType;
  final String? state;
  final String? district;
  final int? price;
  final int? priceMin;
  final int? priceMax;
  final int? bedrooms;
  final int? bathrooms;
  final int? sizeSqft;
  final double? latitude;
  final double? longitude;
  final String summary;
  final List<String> facilities;
  final int palette;
  final String source;
  final String? sourceId;
  final String? scheme;
  final String? projectStatus;
  final String? developerName;
  final int? totalUnits;
  final int? availableUnits;
  final List<String> unitTypes;
  final List<PropertyUnitOption> unitOptions;
  final String? sourceUrl;
  final String? externalProjectUrl;
  final String? developerAddress;
  final String? rawLocation;
  final DateTime? retrievedAt;

  bool get isGovernmentRecord => source.toLowerCase().contains('teduh');

  bool get hasCoordinates => latitude != null && longitude != null;

  double? get pricePerSqft {
    final askingPrice = price;
    final size = sizeSqft;
    if (askingPrice == null || size == null || size == 0) {
      return null;
    }
    return askingPrice / size;
  }

  List<String> get normalizedPropertyTypes {
    final candidates = [
      verifiedPropertyType,
      ...unitOptions.map((option) => option.unitType),
      ...unitTypes,
      type,
    ];
    final categories = <String>{};
    for (final candidate in candidates) {
      final text = candidate?.trim();
      if (text == null || text.isEmpty) {
        continue;
      }
      final normalized = text.toLowerCase();
      if (isGovernmentRecord &&
          (normalized == 'public housing' || normalized == 'public')) {
        continue;
      }
      categories.addAll(PropertyTypeNormalizer.categoriesFor(text));
    }
    return PropertyTypeNormalizer.orderedCategories
        .where(categories.contains)
        .toList();
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      areaId: json['areaId'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      tenure: json['tenure'] as String,
      verifiedPropertyType:
          json['verifiedPropertyType'] as String? ??
          json['property_type'] as String? ??
          json['propertyType'] as String?,
      state: json['state'] as String?,
      district: json['district'] as String?,
      price: _intFromJson(json['price']),
      priceMin: _intFromJson(json['priceMin'] ?? json['price_min']),
      priceMax: _intFromJson(json['priceMax'] ?? json['price_max']),
      bedrooms: _intFromJson(json['bedrooms']),
      bathrooms: _intFromJson(json['bathrooms']),
      sizeSqft: _intFromJson(json['sizeSqft']),
      latitude: _doubleFromJson(json['latitude']),
      longitude: _doubleFromJson(json['longitude']),
      summary: json['summary'] as String,
      facilities: List<String>.from(json['facilities'] as List<dynamic>),
      palette: json['palette'] as int,
      source: json['source'] as String? ?? 'Local sample listing',
      sourceId: json['sourceId'] as String?,
      scheme: json['scheme'] as String?,
      projectStatus: json['projectStatus'] as String?,
      developerName: json['developerName'] as String?,
      totalUnits: _intFromJson(json['totalUnits']),
      availableUnits: _intFromJson(json['availableUnits']),
      unitTypes: (json['unitTypes'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      unitOptions: _unitOptionsFromJson(
        json['unitOptions'] ?? json['unit_options'],
      ),
      sourceUrl: json['sourceUrl'] as String?,
      externalProjectUrl: json['externalProjectUrl'] as String?,
      developerAddress: json['developerAddress'] as String?,
      rawLocation: json['rawLocation'] as String?,
      retrievedAt: _dateTimeFromJson(json['retrievedAt']),
    );
  }

  factory Property.fromTeduhJson(
    Map<String, dynamic> json, {
    required String areaId,
    required int palette,
  }) {
    final sourceId = _stringFromJson(json['source_id'] ?? json['sourceId']);
    final id = _nullableStringFromJson(json['id']) ?? 'teduh_$sourceId';
    final projectName = _stringFromJson(
      json['project_name'] ?? json['projectName'],
    );
    final state = _nullableStringFromJson(json['state']);
    final district = _nullableStringFromJson(json['district']);
    final scheme = _nullableStringFromJson(json['scheme']);
    final tenure = _nullableStringFromJson(json['tenure']);
    final projectStatus = _nullableStringFromJson(
      json['project_status'] ?? json['projectStatus'],
    );
    final priceMin = _intFromJson(json['price_min'] ?? json['priceMin']);
    final priceMax = _intFromJson(json['price_max'] ?? json['priceMax']);
    final type = _nullableStringFromJson(
      json['property_type'] ?? json['propertyType'],
    );
    final developer = _nullableStringFromJson(
      json['developer_name'] ?? json['developerName'],
    );
    final address = _nullableStringFromJson(json['address']);
    final unitTypes = _stringListFromJson(
      json['unit_types'] ?? json['unitTypes'],
    );
    final unitOptions = _unitOptionsFromJson(
      json['unit_options'] ?? json['unitOptions'],
    );
    final facilities = _stringListFromJson(json['facilities']);
    final location = [?district, ?state].join(', ');

    return Property(
      id: id,
      name: projectName,
      areaId: areaId,
      address: address ?? (location.isEmpty ? 'Malaysia' : location),
      type: type ?? '',
      tenure: tenure ?? '',
      verifiedPropertyType: type,
      state: state,
      district: district,
      price: priceMin ?? priceMax,
      priceMin: priceMin,
      priceMax: priceMax,
      latitude: _doubleFromJson(json['latitude']),
      longitude: _doubleFromJson(json['longitude']),
      summary: _teduhSummary(),
      facilities: facilities,
      palette: palette,
      source:
          _nullableStringFromJson(json['source']) ??
          'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: sourceId,
      scheme: scheme,
      projectStatus: projectStatus,
      developerName: developer,
      totalUnits: _intFromJson(json['total_units'] ?? json['totalUnits']),
      availableUnits: _intFromJson(
        json['available_units'] ?? json['availableUnits'],
      ),
      unitTypes: unitTypes,
      unitOptions: unitOptions,
      sourceUrl: _nullableStringFromJson(
        json['source_url'] ?? json['sourceUrl'],
      ),
      externalProjectUrl: _nullableStringFromJson(
        json['external_project_url'] ?? json['externalProjectUrl'],
      ),
      developerAddress: _nullableStringFromJson(
        json['developer_address'] ?? json['developerAddress'],
      ),
      rawLocation: _nullableStringFromJson(
        json['raw_location'] ?? json['rawLocation'],
      ),
      retrievedAt: _dateTimeFromJson(
        json['retrieved_at'] ?? json['retrievedAt'],
      ),
    );
  }

  Map<String, dynamic> toSupabaseJson({DateTime? updatedAt}) {
    return {
      'source_id': sourceId,
      'project_name': name,
      'state': state,
      'district': district,
      'scheme': scheme,
      'price_min': priceMin,
      'price_max': priceMax,
      'property_type': verifiedPropertyType,
      'project_status': projectStatus,
      'developer_name': developerName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'total_units': totalUnits,
      'available_units': availableUnits,
      'unit_types': unitTypes,
      'unit_options': unitOptions.map((option) => option.toJson()).toList(),
      'source': source,
      'source_url': sourceUrl,
      'external_project_url': externalProjectUrl,
      'developer_address': developerAddress,
      'raw_location': rawLocation,
      'retrieved_at': retrievedAt?.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String _teduhSummary() {
    return 'Official housing project information sourced from TEDUH.';
  }

  static String _stringFromJson(Object? value) => value?.toString() ?? '';

  static String? _nullableStringFromJson(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    final text = value.toString().replaceAll(',', '').trim();
    if (text.isEmpty) {
      return null;
    }
    final parsedDouble = double.tryParse(text);
    return parsedDouble?.round();
  }

  static double? _doubleFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final text = value.toString().replaceAll(',', '').trim();
    return double.tryParse(text);
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringListFromJson(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = _nullableStringFromJson(value);
    if (text == null) {
      return const [];
    }
    return text
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<PropertyUnitOption> _unitOptionsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) =>
              PropertyUnitOption.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.hasContent)
        .toList();
  }
}

class PropertyUnitOption {
  const PropertyUnitOption({
    this.sourceUnitId,
    this.unitType,
    this.priceStart,
    this.priceFromText,
    this.sizeSqft,
    this.sizeText,
    this.imageUrl,
  });

  final String? sourceUnitId;
  final String? unitType;
  final int? priceStart;
  final String? priceFromText;
  final int? sizeSqft;
  final String? sizeText;
  final String? imageUrl;

  bool get hasContent =>
      sourceUnitId != null ||
      unitType != null ||
      priceStart != null ||
      priceFromText != null ||
      sizeSqft != null ||
      sizeText != null ||
      imageUrl != null;

  factory PropertyUnitOption.fromJson(Map<String, dynamic> json) {
    return PropertyUnitOption(
      sourceUnitId: Property._nullableStringFromJson(
        json['source_unit_id'] ?? json['sourceUnitId'] ?? json['id'],
      ),
      unitType: Property._nullableStringFromJson(
        json['unit_type'] ?? json['unitType'] ?? json['name'],
      ),
      priceStart: Property._intFromJson(
        json['price_start'] ?? json['priceStart'],
      ),
      priceFromText: Property._nullableStringFromJson(
        json['price_from_text'] ?? json['priceFromText'],
      ),
      sizeSqft: Property._intFromJson(
        json['size_sqft'] ?? json['sizeSqft'] ?? json['base_area'],
      ),
      sizeText: Property._nullableStringFromJson(
        json['size_text'] ?? json['sizeText'],
      ),
      imageUrl: Property._nullableStringFromJson(
        json['image_url'] ?? json['imageUrl'] ?? json['img_url'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (sourceUnitId != null) 'source_unit_id': sourceUnitId,
      if (unitType != null) 'unit_type': unitType,
      if (priceStart != null) 'price_start': priceStart,
      if (priceFromText != null) 'price_from_text': priceFromText,
      if (sizeSqft != null) 'size_sqft': sizeSqft,
      if (sizeText != null) 'size_text': sizeText,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}
