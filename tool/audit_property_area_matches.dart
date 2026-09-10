import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:smart_property_advisor/core/config/supabase_config.dart';
import 'package:smart_property_advisor/core/utils/location_normalizer.dart';
import 'package:smart_property_advisor/core/utils/property_area_resolver.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';

Future<void> main() async {
  if (!SupabaseConfig.isConfigured) {
    stdout.writeln('SUPABASE_NOT_CONFIGURED');
    return;
  }

  final propertyRows = await _fetchRows('properties');
  final profileRows = await _fetchRows('area_profiles');

  final profiles = profileRows
      .map((row) => AreaProfile.fromJson(Map<String, dynamic>.from(row)))
      .toList();
  final areas = _mergeProfileData(
    profiles,
  ).values.map(AreaData.fromProfile).toList();
  final properties = propertyRows.indexed
      .map(
        (entry) => Property.fromTeduhJson(
          Map<String, dynamic>.from(entry.$2),
          areaId: PropertyAreaResolver.resolveAreaIdForLocation(
            sourceAreaId: entry.$2['area_id'] ?? entry.$2['areaId'],
            state: entry.$2['state'],
            district: entry.$2['district'],
            address: entry.$2['address'],
            rawLocation: entry.$2['raw_location'] ?? entry.$2['rawLocation'],
            areas: areas,
          ),
          palette: (entry.$1 + 10) % 12,
        ),
      )
      .toList();

  var matched = 0;
  var unmatched = 0;
  var crossState = 0;
  final suspicious = <String>[];

  for (final property in properties) {
    final area = PropertyAreaResolver.resolve(property: property, areas: areas);
    if (area == null) {
      unmatched += 1;
      continue;
    }

    matched += 1;
    if (!LocationNormalizer.stateMatches(property.state, area.state)) {
      crossState += 1;
      suspicious.add(
        'CROSS_STATE ${property.name}: ${property.state}/${property.district} -> ${area.state}/${area.name}',
      );
      continue;
    }

    final propertyDistrict = LocationNormalizer.canonicalDistrictId(
      property.district,
    );
    final areaDistrict = LocationNormalizer.canonicalDistrictId(area.name);
    if (propertyDistrict.isNotEmpty && propertyDistrict != areaDistrict) {
      suspicious.add(
        'LOCALITY_ALIAS ${property.name}: ${property.state}/${property.district} -> ${area.state}/${area.name}',
      );
    }
  }

  final alamDamai = _firstWhereOrNull(
    properties,
    (property) => property.name.toLowerCase().contains('residensi alam damai'),
  );
  final alamArea = alamDamai == null
      ? null
      : PropertyAreaResolver.resolve(property: alamDamai, areas: areas);

  stdout.writeln('total_properties=${properties.length}');
  stdout.writeln('area_profiles_raw=${profiles.length}');
  stdout.writeln('area_profiles_canonical=${areas.length}');
  stdout.writeln('matched=$matched');
  stdout.writeln('unmatched=$unmatched');
  stdout.writeln('cross_state_mismatches=$crossState');
  stdout.writeln('suspicious_mappings=${suspicious.length}');
  for (final item in suspicious.take(25)) {
    stdout.writeln(item);
  }
  if (alamDamai == null) {
    stdout.writeln('alam_damai=not_found');
  } else if (alamArea == null) {
    stdout.writeln(
      'alam_damai=unmatched property=${alamDamai.state}/${alamDamai.district} area_id=${alamDamai.areaId}',
    );
  } else {
    stdout.writeln(
      'alam_damai=matched property=${alamDamai.state}/${alamDamai.district} area_id=${alamArea.id} area=${alamArea.state}/${alamArea.name}',
    );
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}

Future<List<Map<String, dynamic>>> _fetchRows(String table) async {
  final uri = Uri.parse(
    '${SupabaseConfig.url.replaceAll(RegExp(r'/+$'), '')}/rest/v1/$table',
  ).replace(queryParameters: {'select': '*', 'limit': '5000'});
  final response = await http.get(
    uri,
    headers: {
      'apikey': SupabaseConfig.publishableKey,
      'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
    },
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      'Failed to fetch $table (${response.statusCode}): ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) {
    throw StateError('Unexpected $table response: ${response.body}');
  }
  return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

Map<String, AreaProfile> _mergeProfileData(Iterable<AreaProfile> profiles) {
  final merged = <String, AreaProfile>{};
  for (final profile in profiles) {
    final canonical = profile.canonicalized();
    final existing = merged[canonical.areaId];
    merged[canonical.areaId] = existing == null
        ? canonical
        : existing.mergeWith(canonical);
  }
  return merged;
}
