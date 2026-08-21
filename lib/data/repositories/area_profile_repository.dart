import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/area_profile.dart';

class AreaProfileRepository {
  const AreaProfileRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<List<AreaProfile>> getAreaProfiles({int? limit}) async {
    try {
      var query = _supabase
          .from('area_profiles')
          .select()
          .order('state')
          .order('district');

      if (limit != null) {
        query = query.limit(limit);
      }

      final rows = await query;
      return rows.map((row) => AreaProfile.fromJson(row)).toList();
    } on AreaProfileRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      throw AreaProfileRepositoryException(
        'Failed to load area profiles from Supabase.',
        error,
        stackTrace,
      );
    }
  }
}

class AreaProfileRepositoryException implements Exception {
  const AreaProfileRepositoryException(
    this.message,
    this.cause,
    this.stackTrace,
  );

  final String message;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => '$message Cause: $cause';
}
