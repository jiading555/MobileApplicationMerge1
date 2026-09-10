import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recommendation.dart';
import '../models/user_preferences.dart';

class SavedRecommendationService {
  const SavedRecommendationService();

  SupabaseClient get _supabase => Supabase.instance.client;

  // ============================================================
  // SAVE ONE RECOMMENDATION SESSION
  //
  // One save =
  // - Goal
  // - Budget
  // - State
  // - Area
  // - Property Type
  // - Applied user weights
  // - Current Top 3 recommendation snapshot
  // ============================================================

  Future<void> saveRecommendationSession({
    required List<PropertyRecommendation> recommendations,
    required UserPreferences preferences,
    required List<double> appliedWeights,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Please sign in before saving a recommendation.',
      );
    }

    final topRecommendations =
    recommendations.take(3).toList();

    if (topRecommendations.isEmpty) {
      throw Exception(
        'No recommendation is available to save.',
      );
    }

    final resolvedWeights = _resolveAppliedWeights(
      preferences: preferences,
      appliedWeights: appliedWeights,
    );

    await _supabase
        .from('saved_recommendation_sessions')
        .insert({
      'user_id': user.id,

      'goal': preferences.goal.name,

      'budget': preferences.budget,

      'preferred_state':
      preferences.preferredState.trim().isEmpty
          ? null
          : preferences.preferredState.trim(),

      'preferred_district':
      preferences.preferredDistrict.trim().isEmpty
          ? null
          : preferences.preferredDistrict.trim(),

      'property_type':
      preferences.propertyType == 'Any'
          ? null
          : preferences.propertyType,

      'applied_weights': resolvedWeights,

      'recommendations': [
        for (int index = 0;
        index < topRecommendations.length;
        index++)
          _recommendationSnapshot(
            recommendation:
            topRecommendations[index],
            rank: index + 1,
          ),
      ],
    });
  }

  // ============================================================
  // LOAD ALL SAVED SESSIONS FOR CURRENT USER
  // ============================================================

  Future<List<Map<String, dynamic>>>
  getSavedRecommendationSessions() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await _supabase
        .from('saved_recommendation_sessions')
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

  // ============================================================
  // LOAD ONE SAVED SESSION
  // Useful later for "View Saved Recommendation"
  // ============================================================

  Future<Map<String, dynamic>?>
  getSavedRecommendationSession(
      String id,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('saved_recommendation_sessions')
        .select()
        .eq('id', id)
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      response,
    );
  }

  // ============================================================
  // DELETE SAVED SESSION
  // ============================================================

  Future<void> deleteRecommendationSession(
      String id,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Please sign in before deleting a saved recommendation.',
      );
    }

    await _supabase
        .from('saved_recommendation_sessions')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  // ============================================================
  // BUILD TOP 3 SNAPSHOT
  // ============================================================

  Map<String, dynamic> _recommendationSnapshot({
    required PropertyRecommendation
    recommendation,
    required int rank,
  }) {
    final property =
        recommendation.property;

    final comparablePrice =
        property.price ??
            property.priceMin ??
            property.priceMax;

    return {
      'rank': rank,

      // --------------------------------------------------------
      // Property identity
      // --------------------------------------------------------

      'property_id': property.id,

      'property_name': property.name,

      'address': property.address,

      'state': property.state,

      'district': property.district,

      // Use the same normalized type used by Advisor filtering.
      'property_types':
      property.normalizedPropertyTypes,

      // --------------------------------------------------------
      // Price snapshot
      // --------------------------------------------------------

      'price': comparablePrice,

      'price_min': property.priceMin,

      'price_max': property.priceMax,

      // --------------------------------------------------------
      // Recommendation result
      // --------------------------------------------------------

      'score': recommendation.score,

      'factors': recommendation.factors
          .map(
            (factor) => {
          'label': factor.label,
          'score': factor.score,
          'weight': factor.weight,
          'percentage':
          factor.weight * 100,
          'contribution':
          factor.contribution,
        },
      )
          .toList(),

      'advantages':
      List<String>.from(
        recommendation.reasons,
      ),

      'cautions':
      List<String>.from(
        recommendation.cautions,
      ),

      // --------------------------------------------------------
      // Factual property details
      // Useful if the live property record changes later.
      // --------------------------------------------------------

      'scheme': property.scheme,

      'project_status':
      property.projectStatus,

      'developer_name':
      property.developerName,

      'total_units':
      property.totalUnits,

      'available_units':
      property.availableUnits,

      'unit_types':
      property.unitTypes,

      'unit_options':
      property.unitOptions
          .map(
            (option) =>
            option.toJson(),
      )
          .toList(),

      'source': property.source,
    };
  }

  // ============================================================
  // APPLIED USER WEIGHTS
  //
  // These represent the three priorities shown in Advisor UI.
  // ============================================================

  List<Map<String, dynamic>>
  _resolveAppliedWeights({
    required UserPreferences preferences,
    required List<double> appliedWeights,
  }) {
    final labels =
    preferences.goal ==
        PropertyGoal.ownStay
        ? const [
      'Safety',
      'Education facilities',
      'Transportation',
    ]
        : const [
      'Income / economic indicator',
      'Transportation',
      'Property affordability',
    ];

    List<double> weights;

    if (appliedWeights.length >= 3) {
      weights =
          appliedWeights.take(3).toList();
    } else {
      final priorities =
      preferences.goal ==
          PropertyGoal.ownStay
          ? [
        preferences
            .ownStaySafetyPriority,
        preferences
            .ownStayEducationPriority,
        preferences
            .ownStayTransportPriority,
      ]
          : [
        preferences
            .investmentIncomePriority,
        preferences
            .investmentTransportPriority,
        preferences
            .investmentAffordabilityPriority,
      ];

      weights =
          _normalisePriorities(
            priorities,
          );
    }

    return [
      for (int index = 0;
      index < labels.length;
      index++)
        {
          'label': labels[index],
          'weight': weights[index],
          'percentage':
          weights[index] * 100,
        },
    ];
  }

  // ============================================================
  // FALLBACK WEIGHT NORMALIZATION
  // ============================================================

  List<double> _normalisePriorities(
      List<double> priorities,
      ) {
    final values = priorities
        .map(
          (value) => value
          .clamp(0, 100)
          .toDouble(),
    )
        .toList();

    final total = values.fold<double>(
      0,
          (sum, value) => sum + value,
    );

    if (total <= 0) {
      final equal =
          1.0 / values.length;

      return List<double>.filled(
        values.length,
        equal,
      );
    }

    return values
        .map(
          (value) => value / total,
    )
        .toList();
  }
}