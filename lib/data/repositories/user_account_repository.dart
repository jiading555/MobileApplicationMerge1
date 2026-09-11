import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../../models/user_preferences.dart';

class UserAccountRepository {
  const UserAccountRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<AppUser> loadProfile(User authUser) async {
    final row = await _supabase
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
    final row = await _supabase
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
    await _supabase.from('profiles').upsert({
      'id': user.id,
      'full_name': user.name,
      'phone': user.phone.isEmpty ? null : user.phone,
      'avatar_url': user.avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> savePreferences(String userId, UserPreferences value) async {
    await _supabase.from('user_preferences').upsert({
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
    try {
      final rows = await _supabase
          .from('user_favourites')
          .select('property_id')
          .eq('user_id', userId);
      return rows
          .map((row) => row['property_id']?.toString())
          .whereType<String>()
          .toSet();
    } catch (error, stackTrace) {
      throw UserAccountRepositoryException(
        'Failed to load favourite properties.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> setFavourite({
    required String userId,
    required String propertyId,
    required bool isFavourite,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedPropertyId = propertyId.trim();
    if (trimmedUserId.isEmpty || trimmedPropertyId.isEmpty) {
      throw ArgumentError(
        'Favourite writes require non-empty user_id and property_id.',
      );
    }

    try {
      if (isFavourite) {
        final existing = await _supabase
            .from('user_favourites')
            .select('property_id')
            .eq('user_id', trimmedUserId)
            .eq('property_id', trimmedPropertyId)
            .limit(1);
        if (existing.isNotEmpty) {
          return;
        }

        await _supabase.from('user_favourites').insert({
          'user_id': trimmedUserId,
          'property_id': trimmedPropertyId,
        });
        return;
      }

      await _supabase
          .from('user_favourites')
          .delete()
          .eq('user_id', trimmedUserId)
          .eq('property_id', trimmedPropertyId);
    } catch (error, stackTrace) {
      throw UserAccountRepositoryException(
        'Failed to update favourite property.',
        error,
        stackTrace,
      );
    }
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = extension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final path = '$userId/avatar.$safeExtension';
    await _supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: safeExtension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    return '${_supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}

class UserAccountRepositoryException implements Exception {
  const UserAccountRepositoryException(
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
