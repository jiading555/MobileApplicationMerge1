import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/area_data.dart';
import '../models/area_profile.dart';
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

  Future<List<AreaProfile>> loadProcessedAreaProfiles() async {
    try {
      final source = await rootBundle.loadString(
        'data/processed/area_profiles.json',
      );
      final records = jsonDecode(source) as List<dynamic>;
      return records
          .map((record) => AreaProfile.fromJson(record as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Property>> loadProcessedTeduhProjects(
    List<AreaData> areas,
  ) async {
    try {
      final source = await rootBundle.loadString(
        'data/processed/teduh_projects.json',
      );
      final records = jsonDecode(source) as List<dynamic>;
      return records.indexed.map((entry) {
        final record = entry.$2 as Map<String, dynamic>;
        return Property.fromTeduhJson(
          record,
          areaId: _areaIdForTeduhRecord(record, areas),
          palette: (entry.$1 + 10) % 12,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  String _areaIdForTeduhRecord(
    Map<String, dynamic> record,
    List<AreaData> areas,
  ) {
    final state = _normalise(record['state']);
    final district = _normalise(record['district']);
    for (final area in areas) {
      if (_normalise(area.state) == state &&
          _normalise(area.name) == district) {
        return area.id;
      }
    }
    for (final area in areas) {
      if (_normalise(area.state) == state) {
        return area.id;
      }
    }
    return areas.isEmpty ? 'unknown' : areas.first.id;
  }

  String _normalise(Object? value) {
    return value.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ' ',
    );
  }
}
