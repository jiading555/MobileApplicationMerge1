import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/property_area_resolver.dart';
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
    return PropertyAreaResolver.resolveAreaIdForLocation(
      sourceAreaId: row['area_id'] ?? row['areaId'],
      state: row['state'],
      district: row['district'],
      address: row['address'],
      rawLocation: row['raw_location'] ?? row['rawLocation'],
      areas: areas,
    );
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
