import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/location_normalizer.dart';
import '../../models/area_data.dart';
import '../../models/property.dart';

class PropertyRepository {
  const PropertyRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<Property>> getProperties(List<AreaData> areas) async {
    try {
      final rows = await _supabase
          .from('properties')
          .select()
          .order('state')
          .order('district')
          .order('project_name');

      return rows.indexed
          .map(
            (entry) => Property.fromTeduhJson(
              entry.$2,
              areaId: resolveAreaIdForRow(entry.$2, areas),
              palette: (entry.$1 + 10) % 12,
            ),
          )
          .toList();
    } on PropertyRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      throw PropertyRepositoryException(
        'Failed to load properties from Supabase.',
        error,
        stackTrace,
      );
    }
  }

  Future<int> upsertProperties(List<Property> properties) async {
    if (properties.isEmpty) {
      return 0;
    }

    try {
      final updatedAt = DateTime.now().toUtc();
      await _supabase
          .from('properties')
          .upsert(
            properties
                .map(
                  (property) => property.toSupabaseJson(updatedAt: updatedAt),
                )
                .toList(),
            onConflict: 'source_id',
          );
      return properties.length;
    } catch (error, stackTrace) {
      throw PropertyRepositoryException(
        'Failed to sync TEDUH properties to Supabase.',
        error,
        stackTrace,
      );
    }
  }

  static String resolveAreaIdForRow(
    Map<String, dynamic> row,
    List<AreaData> areas,
  ) {
    final state = LocationNormalizer.canonicalStateId(row['state']);
    final district = LocationNormalizer.canonicalDistrictId(row['district']);
    if (state.isNotEmpty && district.isNotEmpty) {
      final canonicalAreaId = LocationNormalizer.canonicalAreaId(
        row['state'],
        row['district'],
      );
      for (final area in areas) {
        if (LocationNormalizer.areaIdMatches(area.id, canonicalAreaId)) {
          return area.id;
        }
      }
      return canonicalAreaId;
    }
    return 'unknown';
  }
}

class PropertyRepositoryException implements Exception {
  const PropertyRepositoryException(this.message, this.cause, this.stackTrace);

  final String message;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => '$message Cause: $cause';
}
