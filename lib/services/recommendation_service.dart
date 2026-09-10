import '../core/utils/property_filtering.dart';
import '../core/utils/property_area_resolver.dart';
import '../core/utils/location_normalizer.dart';
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
    final results =
        properties
            .where((property) {
              final area = PropertyAreaResolver.resolve(
                property: property,
                areas: areas,
              );
              if (property.price == null || area == null) {
                return false;
              }
              final typeMatches =
                  preferences.propertyType == 'Any' ||
                  PropertyFilterNormalizer.propertyTypeMatches(
                    property,
                    preferences.propertyType,
                  );
              final areaMatches =
                  preferences.preferredAreaId == 'any' ||
                  LocationNormalizer.areaIdMatches(
                    area.id,
                    preferences.preferredAreaId,
                  );
              return typeMatches && areaMatches;
            })
            .map(
              (property) => _score(
                property,
                PropertyAreaResolver.resolve(property: property, areas: areas)!,
                preferences,
              ),
            )
            .toList()
          ..sort((left, right) => right.score.compareTo(left.score));
    return results;
  }

  PropertyRecommendation _score(
    Property property,
    AreaData area,
    UserPreferences preferences,
  ) {
    final affordability = _affordability(property.price!, preferences.budget);
    final factors = preferences.goal == PropertyGoal.ownStay
        ? _ownStayFactors(area, affordability, preferences)
        : _investmentFactors(area, affordability);
    final totalWeight = factors.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    final score =
        factors.fold<double>(0, (sum, item) => sum + item.contribution) /
        totalWeight;
    final reasons = <String>[];
    final cautions = <String>[];

    if (affordability >= 82) {
      reasons.add('Within your RM ${preferences.budget.round()} budget');
    } else if (affordability < 55) {
      cautions.add('Above the selected budget');
    }
    final safetyScore = area.safetyScore;
    final infrastructureScore = area.infrastructureScore;
    final priceGrowth = area.priceGrowth;
    final rentalYield = area.rentalYield;
    if (safetyScore != null && safetyScore >= 76) {
      reasons.add('Strong normalized safety indicator');
    } else if (safetyScore != null && safetyScore < 70) {
      cautions.add('Safety indicator is below the compared-area average');
    }
    if (infrastructureScore != null && infrastructureScore >= 78) {
      reasons.add('Good access to transport and public facilities');
    }
    if (priceGrowth != null && priceGrowth >= 7) {
      reasons.add('Strong historical price-growth signal');
    }
    if (rentalYield != null && rentalYield >= 4.3) {
      reasons.add('Competitive estimated rental yield');
    } else if (preferences.goal == PropertyGoal.investment &&
        rentalYield != null &&
        rentalYield < 4.0) {
      cautions.add('Rental yield is modest compared with other areas');
    }
    if (reasons.length < 3) {
      reasons.add('Balanced value across the selected priorities');
    }
    if (cautions.isEmpty) {
      cautions.add(
        'Verify financing, tenure and property condition independently',
      );
    }

    return PropertyRecommendation(
      property: property,
      score: score.clamp(0, 100).toDouble(),
      factors: factors,
      reasons: reasons.take(4).toList(),
      cautions: cautions.take(2).toList(),
    );
  }

  List<ScoreFactor> _ownStayFactors(
    AreaData area,
    double affordability,
    UserPreferences preferences,
  ) {
    return [
      ScoreFactor(label: 'Affordability', score: affordability, weight: 0.25),
      if (area.safetyScore != null)
        ScoreFactor(
          label: 'Safety',
          score: area.safetyScore!,
          weight: 0.15 + preferences.safetyPriority * 0.12,
        ),
      if (area.transportScore != null)
        ScoreFactor(
          label: 'Accessibility',
          score: area.transportScore!,
          weight: 0.12 + preferences.transportPriority * 0.10,
        ),
      if (area.infrastructureScore != null)
        ScoreFactor(
          label: 'Infrastructure',
          score: area.infrastructureScore!,
          weight: 0.12 + preferences.facilitiesPriority * 0.10,
        ),
      if (area.connectivityScore != null)
        ScoreFactor(
          label: 'Connectivity',
          score: area.connectivityScore!,
          weight: 0.10,
        ),
    ];
  }

  List<ScoreFactor> _investmentFactors(AreaData area, double affordability) {
    return [
      ScoreFactor(label: 'Affordability', score: affordability, weight: 0.15),
      if (area.priceGrowth != null)
        ScoreFactor(
          label: 'Price growth',
          score: (area.priceGrowth! * 10).clamp(0, 100).toDouble(),
          weight: 0.25,
        ),
      if (area.populationGrowth != null)
        ScoreFactor(
          label: 'Population growth',
          score: (area.populationGrowth! * 18).clamp(0, 100).toDouble(),
          weight: 0.20,
        ),
      if (area.rentalYield != null)
        ScoreFactor(
          label: 'Rental yield',
          score: (area.rentalYield! * 18).clamp(0, 100).toDouble(),
          weight: 0.20,
        ),
      if (area.medianIncome != null && area.connectivityScore != null)
        ScoreFactor(
          label: 'Demand signal',
          score: (area.medianIncome! / 120 + area.connectivityScore! * 0.25)
              .clamp(0, 100)
              .toDouble(),
          weight: 0.20,
        ),
    ];
  }

  double _affordability(int price, double budget) {
    if (price <= budget) {
      final unused = (budget - price) / budget;
      return (88 + unused * 12).clamp(0, 100).toDouble();
    }
    final excess = (price - budget) / budget;
    return (88 - excess * 140).clamp(5, 88).toDouble();
  }
}
