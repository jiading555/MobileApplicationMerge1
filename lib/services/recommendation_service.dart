import '../models/area_data.dart';
import '../models/property.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';

class RecommendationService {
  const RecommendationService();

  List<PropertyRecommendation> rank({
    required List<Property> properties,
    required List<AreaData> areas,
    required UserPreferences preferences,
  }) {
    final areaIndex = {
      for (final area in areas) area.id: area,
    };

    final results = properties
        .where((property) {
      final price = property.price;

      if (price == null) {
        return false;
      }

      // Properties without a reliable area mapping are excluded from the
      // area-based advisor.
      if (!areaIndex.containsKey(property.areaId)) {
        return false;
      }

      final typeMatches =
      property.matchesPropertyType(preferences.propertyType);

      final areaMatches =
          preferences.preferredAreaId == 'any' ||
              property.areaId == preferences.preferredAreaId;

      final budgetMatches = price <= preferences.budget;

      return typeMatches && areaMatches && budgetMatches;
    })
        .map((property) {
      return _score(
        property: property,
        price: property.price!,
        area: areaIndex[property.areaId]!,
        areas: areas,
        preferences: preferences,
      );
    })
        .toList();

    results.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      final aPrice = a.property.price ?? 999999999;
      final bPrice = b.property.price ?? 999999999;

      return aPrice.compareTo(bPrice);
    });

    return results;
  }

  PropertyRecommendation _score({
    required Property property,
    required int price,
    required AreaData area,
    required List<AreaData> areas,
    required UserPreferences preferences,
  }) {
    final affordability = _affordability(
      price,
      preferences.budget,
    );

    final factors = preferences.goal == PropertyGoal.ownStay
        ? _ownStayFactors(
      area: area,
      areas: areas,
      preferences: preferences,
    )
        : _investmentFactors(
      area: area,
      areas: areas,
      affordability: affordability,
      preferences: preferences,
    );

    final score = factors.fold<double>(
      0,
          (sum, factor) => sum + factor.contribution,
    );

    final reasons = _buildReasons(
      property: property,
      price: price,
      area: area,
      areas: areas,
      affordability: affordability,
      preferences: preferences,
    );

    final cautions = _buildCautions(
      property: property,
      price: price,
      area: area,
      areas: areas,
      affordability: affordability,
      preferences: preferences,
    );

    return PropertyRecommendation(
      property: property,
      score: score.clamp(0, 100).toDouble(),
      factors: factors,
      reasons: reasons.take(4).toList(),
      cautions: cautions.take(3).toList(),
    );
  }

  List<ScoreFactor> _ownStayFactors({
    required AreaData area,
    required List<AreaData> areas,
    required UserPreferences preferences,
  }) {
    final weights = _normalisePriorities([
      preferences.ownStaySafetyPriority,
      preferences.ownStayEducationPriority,
      preferences.ownStayTransportPriority,
    ]);

    return [
      ScoreFactor(
        label: 'Safety',
        score: area.safetyScore,
        weight: weights[0],
      ),
      ScoreFactor(
        label: 'Education facilities',
        score: _educationScore(area, areas),
        weight: weights[1],
      ),
      ScoreFactor(
        label: 'Transportation',
        score: area.transportScore,
        weight: weights[2],
      ),
    ];
  }

  List<ScoreFactor> _investmentFactors({
    required AreaData area,
    required List<AreaData> areas,
    required double affordability,
    required UserPreferences preferences,
  }) {
    final weights = _normalisePriorities([
      preferences.investmentIncomePriority,
      preferences.investmentTransportPriority,
      preferences.investmentAffordabilityPriority,
    ]);

    return [
      ScoreFactor(
        label: 'Income / economic indicator',
        score: _incomeScore(area, areas),
        weight: weights[0],
      ),
      ScoreFactor(
        label: 'Transportation',
        score: area.transportScore,
        weight: weights[1],
      ),
      ScoreFactor(
        label: 'Property affordability',
        score: affordability,
        weight: weights[2],
      ),
    ];
  }

  List<double> _normalisePriorities(List<double> priorities) {
    final values = priorities
        .map((value) => value.clamp(0, 100).toDouble())
        .toList();

    final total = values.fold<double>(
      0,
          (sum, value) => sum + value,
    );

    if (total <= 0) {
      final equal = 1.0 / values.length;
      return List<double>.filled(values.length, equal);
    }

    return values.map((value) => value / total).toList();
  }

  double _educationScore(
      AreaData area,
      List<AreaData> areas,
      ) {
    return _normalize(
      area.schools.toDouble(),
      areas.map((item) => item.schools.toDouble()).toList(),
    );
  }

  double _incomeScore(
      AreaData area,
      List<AreaData> areas,
      ) {
    return _normalize(
      area.medianIncome.toDouble(),
      areas.map((item) => item.medianIncome.toDouble()).toList(),
    );
  }

  double _normalize(
      double value,
      List<double> values,
      ) {
    if (values.isEmpty) {
      return 50;
    }

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    if (maxValue == minValue) {
      return 50;
    }

    return ((value - minValue) / (maxValue - minValue) * 100)
        .clamp(0, 100)
        .toDouble();
  }

  double _affordability(
      int price,
      double budget,
      ) {
    if (budget <= 0) {
      return 0;
    }

    final ratio = price / budget;

    return ((1 - ratio) * 100 + 75)
        .clamp(0, 100)
        .toDouble();
  }

  List<String> _buildReasons({
    required Property property,
    required int price,
    required AreaData area,
    required List<AreaData> areas,
    required double affordability,
    required UserPreferences preferences,
  }) {
    final reasons = <String>[];

    if (preferences.goal == PropertyGoal.ownStay) {
      final education = _educationScore(area, areas);

      if (area.safetyScore >= 75) {
        reasons.add('Good safety performance for own-stay living');
      }

      if (education >= 65) {
        reasons.add('Strong education facility availability');
      }

      if (area.transportScore >= 80) {
        reasons.add('Good transportation accessibility');
      }

      if (price <= preferences.budget * 0.85) {
        reasons.add('Comfortably within your selected budget');
      }
    } else {
      final income = _incomeScore(area, areas);

      if (income >= 65) {
        reasons.add('Strong household income and economic indicator');
      }

      if (area.transportScore >= 80) {
        reasons.add('Good transportation accessibility');
      }

      if (affordability >= 80) {
        reasons.add('Good affordability within your investment budget');
      }
    }

    if (property.normalizedPropertyTypes.isNotEmpty) {
      reasons.add(
        'Available unit type: ${property.normalizedPropertyTypes.join(', ')}',
      );
    }

    if (reasons.isEmpty) {
      reasons.add('Balanced performance across the selected indicators');
    }

    return reasons;
  }

  List<String> _buildCautions({
    required Property property,
    required int price,
    required AreaData area,
    required List<AreaData> areas,
    required double affordability,
    required UserPreferences preferences,
  }) {
    final cautions = <String>[];

    if (preferences.goal == PropertyGoal.ownStay) {
      final education = _educationScore(area, areas);

      if (area.safetyScore < 70) {
        cautions.add('Safety indicator is relatively low');
      }

      if (education < 45) {
        cautions.add(
          'Education facility availability is lower than stronger compared areas',
        );
      }

      if (area.transportScore < 70) {
        cautions.add('Transportation accessibility is relatively limited');
      }

      if (price > preferences.budget * 0.95) {
        cautions.add('Property price is close to your maximum budget');
      }
    } else {
      final income = _incomeScore(area, areas);

      if (income < 40) {
        cautions.add('Household income indicator is relatively low');
      }

      if (area.transportScore < 70) {
        cautions.add('Transportation accessibility may limit demand');
      }

      if (affordability < 70) {
        cautions.add(
          'Property uses a large portion of the selected investment budget',
        );
      }
    }

    if (cautions.isEmpty) {
      cautions.add(
        'Review financing, tenure and property condition before making a final decision',
      );
    }

    return cautions;
  }
}
