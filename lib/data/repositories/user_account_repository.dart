import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../models/user_preferences.dart';

class UserAccountRepository {
  const UserAccountRepository();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AppUser> loadProfile(User authUser) async {
    final row = await _client
        .from('profiles')
        .select('id, full_name, phone, avatar_url')
        .eq('id', authUser.id)
        .maybeSingle();
    return AppUser(
      id: authUser.id,
      name: (row?['full_name'] as String?)?.trim().isNotEmpty == true
          ? row!['full_name'] as String
          : (authUser.userMetadata?['full_name'] as String?) ?? 'User',
      email: authUser.email ?? '',
      phone: (row?['phone'] as String?) ?? '',
      avatarUrl: row?['avatar_url'] as String?,
    );
  }

  Future<UserPreferences> loadPreferences(String userId) async {
    final row = await _client
        .from('user_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const UserPreferences();
    final min = (row['minimum_budget'] as num?)?.toDouble() ?? 350000;
    final max = (row['maximum_budget'] as num?)?.toDouble() ?? 900000;
    return UserPreferences(
      budget: max,
      minimumBudget: min,
      maximumBudget: max,
      preferredState: (row['preferred_state'] as String?) ?? '',
      preferredDistrict: (row['preferred_district'] as String?) ?? '',
      propertyType: (row['preferred_property_type'] as String?) ?? 'Any',
    );
  }

  Future<void> saveProfile(AppUser user) async {
    await _client.from('profiles').upsert({
      'id': user.id,
      'full_name': user.name,
      'phone': user.phone.isEmpty ? null : user.phone,
      'avatar_url': user.avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> savePreferences(String userId, UserPreferences value) async {
    await _client.from('user_preferences').upsert({
      'user_id': userId,
      'preferred_state': value.preferredState.isEmpty
          ? null
          : value.preferredState,
      'preferred_district': value.preferredDistrict.isEmpty
          ? null
          : value.preferredDistrict,
      'preferred_property_type': value.propertyType == 'Any'
          ? null
          : value.propertyType,
      'minimum_budget': value.minimumBudget,
      'maximum_budget': value.maximumBudget,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Set<String>> loadFavouritePropertyIds(String userId) async {
    final rows = await _client
        .from('user_favourites')
        .select('property_id')
        .eq('user_id', userId);
    return rows
        .map((row) => row['property_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<void> setFavourite({
    required String userId,
    required String propertyId,
    required bool isFavourite,
  }) async {
    if (isFavourite) {
      await _client.from('user_favourites').upsert({
        'user_id': userId,
        'property_id': propertyId,
      });
      return;
    }

    await _client
        .from('user_favourites')
        .delete()
        .eq('user_id', userId)
        .eq('property_id', propertyId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = extension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final path = '$userId/avatar.$safeExtension';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: safeExtension == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );
    return '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
