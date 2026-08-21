import 'package:flutter/foundation.dart';

import '../data/repositories/area_profile_repository.dart';

class SupabaseConnectionVerifier {
  const SupabaseConnectionVerifier._();

  static Future<void> logFirstAreaProfile({
    AreaProfileRepository repository = const AreaProfileRepository(),
  }) async {
    try {
      final profiles = await repository.getAreaProfiles(limit: 1);
      if (profiles.isEmpty) {
        debugPrint(
          '[DEV Supabase check] area_profiles query succeeded, but no rows '
          'were returned.',
        );
        return;
      }

      final profile = profiles.first;
      debugPrint('[DEV Supabase check] Supabase connection successful');
      debugPrint(
        '[DEV Supabase check] Area: ${profile.district}, ${profile.state}',
      );
    } on AreaProfileRepositoryException catch (error) {
      debugPrint('[DEV Supabase check] area_profiles query failed: $error');
    }
  }
}
