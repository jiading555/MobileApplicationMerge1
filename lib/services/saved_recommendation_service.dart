import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recommendation.dart';
import '../models/user_preferences.dart';

class SavedRecommendationService {
  const SavedRecommendationService();

  SupabaseClient get _supabase =>
      Supabase.instance.client;

  Future<void> saveRecommendation({
    required PropertyRecommendation recommendation,
    required PropertyGoal goal,
    String? aiSummary,
  }) async {
    final property = recommendation.property;
    final user = _supabase.auth.currentUser;

    await _supabase
        .from('saved_recommendations')
        .insert({
      'user_id': user?.id,
      'property_id': property.id,
      'property_name': property.name,
      'address': property.address,
      'property_type': property.type,
      'price': property.price,
      'goal': goal.name,
      'score': recommendation.score,
      'ai_summary': aiSummary,

      'factors': recommendation.factors
          .map(
            (factor) => {
          'label': factor.label,
          'score': factor.score,
          'weight': factor.weight,
          'contribution':
          factor.contribution,
        },
      )
          .toList(),

      'advantages':
      recommendation.reasons,

      'cautions':
      recommendation.cautions,
    });
  }

  Future<List<Map<String, dynamic>>>
  getSavedRecommendations() async {
    final user = _supabase.auth.currentUser;

    dynamic query =
    _supabase.from(
      'saved_recommendations',
    );

    if (user != null) {
      final response = await query
          .select()
          .eq('user_id', user.id)
          .order(
        'created_at',
        ascending: false,
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    }

    final response = await query
        .select()
        .isFilter('user_id', null)
        .order(
      'created_at',
      ascending: false,
    );

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  Future<void> deleteRecommendation(
      String id,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      await _supabase
          .from('saved_recommendations')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      return;
    }

    await _supabase
        .from('saved_recommendations')
        .delete()
        .eq('id', id)
        .isFilter('user_id', null);
  }
}