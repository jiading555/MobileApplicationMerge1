import 'package:supabase_flutter/supabase_flutter.dart';

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
              areaId: _areaIdForRow(entry.$2, areas),
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

  String _areaIdForRow(Map<String, dynamic> row, List<AreaData> areas) {
    final state = _normalise(row['state']);
    final district = _normalise(row['district']);
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

class PropertyRepositoryException implements Exception {
  const PropertyRepositoryException(this.message, this.cause, this.stackTrace);

  final String message;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => '$message Cause: $cause';
}
