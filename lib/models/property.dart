class Property {
  const Property({
    required this.id,
    required this.name,
    required this.areaId,
    required this.address,
    required this.type,
    required this.tenure,
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

  /// User-friendly property categories derived from TEDUH `unit_types`.
  ///
  /// A project may belong to more than one category. For example, a project
  /// containing both RUMAH TERES and RUMAH BERKEMBAR can match both Terrace
  /// and Semi-D filters.
  List<String> get normalizedPropertyTypes {
    final result = <String>{};

    for (final unitType in unitTypes) {
      final normalized = _normalizePropertyType(unitType);
      if (normalized != null) {
        result.add(normalized);
      }
    }

    // Compatibility for local JSON or older records that only have `type`.
    if (result.isEmpty) {
      final normalized = _normalizePropertyType(type);
      if (normalized != null) {
        result.add(normalized);
      }
    }

    final values = result.toList()..sort();
    return values;
  }

  bool matchesPropertyType(String selectedType) {
    if (selectedType == 'Any') {
      return true;
    }

    return normalizedPropertyTypes.contains(selectedType);
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      areaId: json['areaId'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      tenure: json['tenure'] as String,
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
    final projectName = _stringFromJson(
      json['project_name'] ?? json['projectName'],
    );
    final state = _nullableStringFromJson(json['state']);
    final district = _nullableStringFromJson(json['district']);
    final scheme = _nullableStringFromJson(json['scheme']);
    final projectStatus = _nullableStringFromJson(
      json['project_status'] ?? json['projectStatus'],
    );
    final priceMin = _intFromJson(json['price_min'] ?? json['priceMin']);
    final priceMax = _intFromJson(json['price_max'] ?? json['priceMax']);
    final rawPropertyType = _nullableStringFromJson(
      json['property_type'] ?? json['propertyType'],
    );
    final developer = _nullableStringFromJson(
      json['developer_name'] ?? json['developerName'],
    );
    final address = _nullableStringFromJson(json['address']);
    final unitTypes = _stringListFromJson(
      json['unit_types'] ?? json['unitTypes'],
    );
    final location = [?district, ?state].join(', ');

    final displayType = rawPropertyType ??
        _displayTypeFromUnitTypes(unitTypes) ??
        'Public housing';

    return Property(
      id: _nullableStringFromJson(json['id']) ?? 'teduh_$sourceId',
      name: projectName,
      areaId: areaId,
      address: address ?? (location.isEmpty ? 'Malaysia' : location),
      type: displayType,
      tenure: scheme ?? 'Government housing',
      state: state,
      district: district,
      price: priceMin ?? priceMax,
      priceMin: priceMin,
      priceMax: priceMax,
      latitude: _doubleFromJson(json['latitude']),
      longitude: _doubleFromJson(json['longitude']),
      summary: _teduhSummary(
        scheme: scheme,
        developer: developer,
        totalUnits: _intFromJson(json['total_units'] ?? json['totalUnits']),
        availableUnits: _intFromJson(
          json['available_units'] ?? json['availableUnits'],
        ),
      ),
      facilities: [?scheme, ?developer, ?state],
      palette: palette,
      source: _nullableStringFromJson(json['source']) ??
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

  Map<String, dynamic> toSupabaseJson() {
    return {
      'source_id': sourceId,
      'project_name': name,
      'state': state,
      'district': district,
      'scheme': scheme,
      'price_min': priceMin,
      'price_max': priceMax,
      'property_type': type,
      'project_status': projectStatus,
      'developer_name': developerName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'total_units': totalUnits,
      'available_units': availableUnits,
      'unit_types': unitTypes,
      'source': source,
      'source_url': sourceUrl,
      'external_project_url': externalProjectUrl,
      'developer_address': developerAddress,
      'raw_location': rawLocation,
      'retrieved_at': retrievedAt?.toUtc().toIso8601String(),
    };
  }

  static String _teduhSummary({
    required String? scheme,
    required String? developer,
    required int? totalUnits,
    required int? availableUnits,
  }) {
    final parts = [
      'Public housing/project record from TEDUH.',
      if (scheme != null) 'Scheme: $scheme.',
      if (developer != null) 'Developer: $developer.',
      if (totalUnits != null) 'Total units: $totalUnits.',
      if (availableUnits != null) 'Available units: $availableUnits.',
    ];
    return parts.join(' ');
  }

  static String? _displayTypeFromUnitTypes(List<String> unitTypes) {
    final categories = <String>{};

    for (final unitType in unitTypes) {
      final normalized = _normalizePropertyType(unitType);
      if (normalized != null) {
        categories.add(normalized);
      }
    }

    if (categories.isEmpty) {
      return null;
    }

    final sorted = categories.toList()..sort();
    return sorted.join(' / ');
  }

  static String? _normalizePropertyType(String value) {
    final text = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[-_/]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (text.isEmpty) {
      return null;
    }

    if (text.contains('KONDOMINIUM') ||
        text.contains('CONDOMINIUM')) {
      return 'Condominium';
    }

    if (text.contains('PANGSAPURI') ||
        text.contains('APARTMEN') ||
        text.contains('APARTMENT')) {
      return 'Apartment';
    }

    if (text.contains('BERKEMBAR') ||
        text.contains('SEMI D') ||
        text.contains('SEMI-D')) {
      return 'Semi-D';
    }

    if (text.contains('TERES')) {
      return 'Terrace';
    }

    if (text.contains('RUMAH BANDAR') ||
        text.contains('TOWNHOUSE') ||
        text.contains('TOWN HOUSE')) {
      return 'Townhouse';
    }

    if (text.contains('RUMAH KEDAI') ||
        text.contains('SHOP HOUSE') ||
        text.contains('SHOPHOUSE') ||
        text.contains('SHOP LOT') ||
        text.contains('SHOPLOT')) {
      return 'Shop House';
    }

    if (text.contains('BANGLO') ||
        text.contains('BUNGALOW')) {
      return 'Bungalow';
    }

    if (text.contains('FLAT')) {
      return 'Flat';
    }

    if (text.contains('KLUSTER') ||
        text.contains('CLUSTER')) {
      return 'Cluster House';
    }

    if (text.contains('STUDIO')) {
      return 'Studio';
    }

    return 'Other';
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
    return int.tryParse(text);
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
}
