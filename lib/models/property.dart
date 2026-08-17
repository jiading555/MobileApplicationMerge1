class Property {
  const Property({
    required this.id,
    required this.name,
    required this.areaId,
    required this.address,
    required this.type,
    required this.tenure,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.sizeSqft,
    required this.latitude,
    required this.longitude,
    required this.summary,
    required this.facilities,
    required this.palette,
  });

  final String id;
  final String name;
  final String areaId;
  final String address;
  final String type;
  final String tenure;
  final int price;
  final int bedrooms;
  final int bathrooms;
  final int sizeSqft;
  final double latitude;
  final double longitude;
  final String summary;
  final List<String> facilities;
  final int palette;

  double get pricePerSqft => price / sizeSqft;

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      areaId: json['areaId'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      tenure: json['tenure'] as String,
      price: json['price'] as int,
      bedrooms: json['bedrooms'] as int,
      bathrooms: json['bathrooms'] as int,
      sizeSqft: json['sizeSqft'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      summary: json['summary'] as String,
      facilities: List<String>.from(json['facilities'] as List<dynamic>),
      palette: json['palette'] as int,
    );
  }
}
