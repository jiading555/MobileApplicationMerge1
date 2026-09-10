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

  Future<int> upsertAreaProfiles(List<AreaProfile> profiles) async {
    if (profiles.isEmpty) {
      return 0;
    }

    try {
      final updatedAt = DateTime.now().toUtc();
      final incomingByAreaId = mergeProfileData(profiles);
      final existingRows = await _supabase
          .from('area_profiles')
          .select()
          .inFilter('area_id', incomingByAreaId.keys.toList());
      final mergedByAreaId = mergeProfileData([
        ...existingRows.map((row) => AreaProfile.fromJson(row)),
        ...incomingByAreaId.values,
      ]);
      await _supabase
          .from('area_profiles')
          .upsert(
            mergedByAreaId.values
                .map((profile) => profile.toSupabaseJson(updatedAt: updatedAt))
                .toList(),
            onConflict: 'area_id',
          );
      return mergedByAreaId.length;
    } catch (error, stackTrace) {
      throw AreaProfileRepositoryException(
        'Failed to sync area profiles to Supabase.',
        error,
        stackTrace,
      );
    }
  }

  static Map<String, AreaProfile> mergeProfileData(
    Iterable<AreaProfile> profiles,
  ) {
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
