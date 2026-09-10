import '../core/utils/location_normalizer.dart';
import '../core/utils/property_area_resolver.dart';
import '../core/utils/property_filtering.dart';
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
    final results = <PropertyRecommendation>[];

    for (final property in properties) {
      final price = property.price ?? property.priceMin ?? property.priceMax;
      final area = PropertyAreaResolver.resolve(
        property: property,
        areas: areas,
      );
      if (price == null || area == null) {
        continue;
      }
      if (!_matchesPreferences(
        property: property,
        price: price,
        area: area,
        areas: areas,
        preferences: preferences,
      )) {
        continue;
      }

      results.add(
        _score(
          property: property,
          price: price,
          area: area,
          areas: areas,
          preferences: preferences,
        ),
      );
    }

    results.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final leftPrice =
          left.property.price ??
              left.property.priceMin ??
              left.property.priceMax;
      final rightPrice =
          right.property.price ??
              right.property.priceMin ??
              right.property.priceMax;
      return (leftPrice ?? 999999999).compareTo(rightPrice ?? 999999999);
    });

    return results;
  }

  bool _matchesPreferences({
    required Property property,
    required int price,
    required AreaData area,
    required Iterable<AreaData> areas,
    required UserPreferences preferences,
  }) {
    final typeMatches =
        preferences.propertyType == 'Any' ||
            PropertyFilterNormalizer.propertyTypeMatches(
              property,
              preferences.propertyType,
            );

    final budgetMatches = price <= _effectiveBudget(preferences);

    final propertyState =
    LocationNormalizer.nullableDisplayStateName(property.state);
    final propertyDistrict =
    LocationNormalizer.nullableDisplayDistrictName(property.district);

    final preferredState = preferences.preferredState.trim();
    final preferredDistrict = preferences.preferredDistrict.trim();

    final stateMatches =
        preferredState.isEmpty ||
            (propertyState != null &&
                LocationNormalizer.stateMatches(
                  propertyState,
                  preferredState,
                ));

    final districtMatches =
        preferredDistrict.isEmpty ||
            (propertyDistrict != null &&
                LocationNormalizer.districtMatches(
                  propertyDistrict,
                  preferredDistrict,
                  state: propertyState,
                ));

    final areaMatches =
    preferredDistrict.isNotEmpty ||
        preferences.preferredAreaId == 'any'
        ? true
        : PropertyAreaResolver.matchesSelectedArea(
      property: property,
      selectedAreaId: preferences.preferredAreaId,
      areas: areas,
    );

    return typeMatches &&
        areaMatches &&
        budgetMatches &&
        stateMatches &&
        districtMatches;
  }

  PropertyRecommendation _score({
    required Property property,
    required int price,
    required AreaData area,
    required List<AreaData> areas,
    required UserPreferences preferences,
  }) {
    final affordability = _affordability(price, _effectiveBudget(preferences));
    final factors = preferences.goal == PropertyGoal.ownStay
        ? _ownStayFactors(
      area: area,
      areas: areas,
      affordability: affordability,
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
    required double affordability,
    required UserPreferences preferences,
  }) {
    return _weightedFactors([
      _WeightedScore(
        label: 'Safety',
        score: area.safetyScore,
        priority: preferences.ownStaySafetyPriority,
      ),
      _WeightedScore(
        label: 'Education facilities',
        score: _educationScore(area, areas),
        priority: preferences.ownStayEducationPriority,
      ),
      _WeightedScore(
        label: 'Transportation',
        score: area.transportScore,
        priority: preferences.ownStayTransportPriority,
      ),
      _WeightedScore(
        label: 'Affordability',
        score: affordability,
        priority: 10,
      ),
    ]);
  }

  List<ScoreFactor> _investmentFactors({
    required AreaData area,
    required List<AreaData> areas,
    required double affordability,
    required UserPreferences preferences,
  }) {
    return _weightedFactors([
      _WeightedScore(
        label: 'Income / economic indicator',
        score: _incomeScore(area, areas),
        priority: preferences.investmentIncomePriority,
      ),
      _WeightedScore(
        label: 'Transportation',
        score: area.transportScore,
        priority: preferences.investmentTransportPriority,
      ),
      _WeightedScore(
        label: 'Property affordability',
        score: affordability,
        priority: preferences.investmentAffordabilityPriority,
      ),
      _WeightedScore(
        label: 'Price growth',
        score: _percentageSignal(area.priceGrowth, multiplier: 10),
        priority: 8,
      ),
      _WeightedScore(
        label: 'Rental yield',
        score: _percentageSignal(area.rentalYield, multiplier: 18),
        priority: 8,
      ),
    ]);
  }

  List<ScoreFactor> _weightedFactors(List<_WeightedScore> candidates) {
    final available = candidates
        .where((item) => item.score != null && item.priority > 0)
        .toList(growable: false);
    if (available.isEmpty) {
      return const [ScoreFactor(label: 'Available data', score: 50, weight: 1)];
    }
    final weights = _normalisePriorities(
      available.map((item) => item.priority).toList(),
    );
    return [
      for (var index = 0; index < available.length; index++)
        ScoreFactor(
          label: available[index].label,
          score: available[index].score!.clamp(0, 100).toDouble(),
          weight: weights[index],
        ),
    ];
  }

  List<double> _normalisePriorities(List<double> priorities) {
    final values = priorities
        .map((value) => value.clamp(0, 100).toDouble())
        .toList();
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      final equal = 1.0 / values.length;
      return List<double>.filled(values.length, equal);
    }
    return values.map((value) => value / total).toList();
  }

  double? _educationScore(AreaData area, List<AreaData> areas) {
    final schools = area.schools;
    if (schools == null) {
      return null;
    }
    return _normalize(
      schools.toDouble(),
      areas
          .map((item) => item.schools?.toDouble())
          .whereType<double>()
          .toList(),
    );
  }

  double? _incomeScore(AreaData area, List<AreaData> areas) {
    final income = area.medianIncome;
    if (income == null) {
      return null;
    }
    return _normalize(
      income.toDouble(),
      areas
          .map((item) => item.medianIncome?.toDouble())
          .whereType<double>()
          .toList(),
    );
  }

  double _normalize(double value, List<double> values) {
    if (values.isEmpty) {
      return 50;
    }
    final minValue = values.reduce(
          (left, right) => left < right ? left : right,
    );
    final maxValue = values.reduce(
          (left, right) => left > right ? left : right,
    );
    if (maxValue == minValue) {
      return 50;
    }
    return ((value - minValue) / (maxValue - minValue) * 100)
        .clamp(0, 100)
        .toDouble();
  }

  double _affordability(int price, double budget) {
    if (budget <= 0) {
      return 0;
    }
    final ratio = price / budget;
    return ((1 - ratio) * 100 + 75).clamp(0, 100).toDouble();
  }

  double _effectiveBudget(UserPreferences preferences) {
    if (preferences.budget > 0) {
      return preferences.budget;
    }
    if (preferences.maximumBudget > 0) {
      return preferences.maximumBudget;
    }
    return 0;
  }

  double? _percentageSignal(double? value, {required double multiplier}) {
    if (value == null) {
      return null;
    }
    return (value * multiplier).clamp(0, 100).toDouble();
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
      final safetyScore = area.safetyScore;
      final transportScore = area.transportScore;

      if (safetyScore != null && safetyScore >= 75) {
        reasons.add('Good safety performance for own-stay living');
      }
      if (education != null && education >= 65) {
        reasons.add('Strong education facility availability');
      }
      if (transportScore != null && transportScore >= 80) {
        reasons.add('Good transportation accessibility');
      }
      if (price <= _effectiveBudget(preferences) * 0.85) {
        reasons.add('Comfortably within your selected budget');
      }
    } else {
      final income = _incomeScore(area, areas);
      final transportScore = area.transportScore;

      if (income != null && income >= 65) {
        reasons.add('Strong household income and economic indicator');
      }
      if (transportScore != null && transportScore >= 80) {
        reasons.add('Good transportation accessibility');
      }
      if (affordability >= 80) {
        reasons.add('Good affordability within your investment budget');
      }
      if (area.priceGrowth != null && area.priceGrowth! >= 7) {
        reasons.add('Strong historical price-growth signal');
      }
      if (area.rentalYield != null && area.rentalYield! >= 4.3) {
        reasons.add('Competitive estimated rental yield');
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
    required int price,
    required AreaData area,
    required List<AreaData> areas,
    required double affordability,
    required UserPreferences preferences,
  }) {
    final cautions = <String>[];

    if (preferences.goal == PropertyGoal.ownStay) {
      final education = _educationScore(area, areas);
      final safetyScore = area.safetyScore;
      final transportScore = area.transportScore;

      if (safetyScore != null && safetyScore < 70) {
        cautions.add('Safety indicator is relatively low');
      }
      if (education != null && education < 45) {
        cautions.add(
          'Education facility availability is lower than stronger compared areas',
        );
      }
      if (transportScore != null && transportScore < 70) {
        cautions.add('Transportation accessibility is relatively limited');
      }
      if (price > _effectiveBudget(preferences) * 0.95) {
        cautions.add('Property price is close to your maximum budget');
      }
    } else {
      final income = _incomeScore(area, areas);
      final transportScore = area.transportScore;

      if (income != null && income < 40) {
        cautions.add('Household income indicator is relatively low');
      }
      if (transportScore != null && transportScore < 70) {
        cautions.add(
          'Transportation accessibility indicator is relatively low',
        );
      }
      if (affordability < 70) {
        cautions.add(
          'Property uses a large portion of the selected investment budget',
        );
      }
      if (area.rentalYield != null && area.rentalYield! < 4.0) {
        cautions.add('Rental yield is modest compared with other areas');
      }
    }

    if (cautions.isEmpty) {
      cautions.add(
        'No major caution was identified from the currently available scoring indicators',
      );
    }
    return cautions;
  }
}

class _WeightedScore {
  const _WeightedScore({
    required this.label,
    required this.score,
    required this.priority,
  });

  final String label;
  final double? score;
  final double priority;
}
