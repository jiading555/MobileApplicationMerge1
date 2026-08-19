import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/area_data.dart';
import '../models/property.dart';

class AssetRepository {
  const AssetRepository();

  Future<List<AreaData>> loadAreas() async {
    final source = await rootBundle.loadString('assets/data/areas.json');
    final records = jsonDecode(source) as List<dynamic>;
    return records
        .map((record) => AreaData.fromJson(record as Map<String, dynamic>))
        .toList();
  }

  Future<List<Property>> loadProperties() async {
    final source = await rootBundle.loadString('assets/data/properties.json');
    final records = jsonDecode(source) as List<dynamic>;
    return records
        .map((record) => Property.fromJson(record as Map<String, dynamic>))
        .toList();
  }
}
