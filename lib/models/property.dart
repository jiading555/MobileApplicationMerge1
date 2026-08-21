class Property {
  const Property({
    required this.id,
    required this.name,
    required this.areaId,
    required this.address,
    required this.type,
    required this.tenure,
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
    this.developerName,
    this.totalUnits,
    this.availableUnits,
    this.sourceUrl,
    this.retrievedAt,
  });

  final String id;
  final String name;
  final String areaId;
  final String address;
  final String type;
  final String tenure;
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
  final String? developerName;
  final int? totalUnits;
  final int? availableUnits;
  final String? sourceUrl;
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

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      areaId: json['areaId'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      tenure: json['tenure'] as String,
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
      developerName: json['developerName'] as String?,
      totalUnits: _intFromJson(json['totalUnits']),
      availableUnits: _intFromJson(json['availableUnits']),
      sourceUrl: json['sourceUrl'] as String?,
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
    final priceMin = _intFromJson(json['price_min'] ?? json['priceMin']);
    final priceMax = _intFromJson(json['price_max'] ?? json['priceMax']);
    final type = _nullableStringFromJson(
      json['property_type'] ?? json['propertyType'],
    );
    final developer = _nullableStringFromJson(
      json['developer_name'] ?? json['developerName'],
    );
    final location = [?district, ?state].join(', ');

    return Property(
      id: 'teduh_$sourceId',
      name: projectName,
      areaId: areaId,
      address: location.isEmpty ? 'Malaysia' : location,
      type: type ?? 'Public housing',
      tenure: scheme ?? 'Government housing',
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
      source:
          _nullableStringFromJson(json['source']) ??
          'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: sourceId,
      scheme: scheme,
      developerName: developer,
      totalUnits: _intFromJson(json['total_units'] ?? json['totalUnits']),
      availableUnits: _intFromJson(
        json['available_units'] ?? json['availableUnits'],
      ),
      sourceUrl: _nullableStringFromJson(
        json['source_url'] ?? json['sourceUrl'],
      ),
      retrievedAt: _dateTimeFromJson(
        json['retrieved_at'] ?? json['retrievedAt'],
      ),
    );
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
    return int.tryParse(value.toString());
  }

  static double? _doubleFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
