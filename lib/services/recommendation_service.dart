import '../core/constants/property_preference_options.dart';
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
    final areaIndex = {for (final area in areas) area.id: area};
    final results =
        properties
            .where((property) {
              if (property.price == null ||
                  !areaIndex.containsKey(property.areaId)) {
                return false;
              }
              final typeMatches =
                  PropertyPreferenceOptions.matchesPropertyType(
                    preferences.propertyType,
                    property.type,
                  );
              final areaMatches =
                  preferences.preferredAreaId == 'any' ||
                  property.areaId == preferences.preferredAreaId;
              final stateMatches = preferences.preferredState.isEmpty ||
                  _normalise(property.state) ==
                      _normalise(preferences.preferredState);
              final districtMatches =
                  preferences.preferredDistrict.isEmpty ||
                  _normalise(property.district) ==
                      _normalise(preferences.preferredDistrict);
              return typeMatches &&
                  areaMatches &&
                  stateMatches &&
                  districtMatches;
            })
            .map(
              (property) =>
                  _score(property, areaIndex[property.areaId]!, preferences),
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
    if (area.safetyScore >= 76) {
      reasons.add('Strong normalized safety indicator');
    } else if (area.safetyScore < 70) {
      cautions.add('Safety indicator is below the compared-area average');
    }
    if (area.infrastructureScore >= 78) {
      reasons.add('Good access to transport and public facilities');
    }
    if (area.priceGrowth >= 7) {
      reasons.add('Strong historical price-growth signal');
    }
    if (area.rentalYield >= 4.3) {
      reasons.add('Competitive estimated rental yield');
    } else if (preferences.goal == PropertyGoal.investment &&
        area.rentalYield < 4.0) {
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
      ScoreFactor(
        label: 'Safety',
        score: area.safetyScore,
        weight: 0.15 + preferences.safetyPriority * 0.12,
      ),
      ScoreFactor(
        label: 'Accessibility',
        score: area.transportScore,
        weight: 0.12 + preferences.transportPriority * 0.10,
      ),
      ScoreFactor(
        label: 'Infrastructure',
        score: area.infrastructureScore,
        weight: 0.12 + preferences.facilitiesPriority * 0.10,
      ),
      ScoreFactor(
        label: 'Connectivity',
        score: area.connectivityScore,
        weight: 0.10,
      ),
    ];
  }

  List<ScoreFactor> _investmentFactors(AreaData area, double affordability) {
    final growth = (area.priceGrowth * 10).clamp(0, 100).toDouble();
    final population = (area.populationGrowth * 18).clamp(0, 100).toDouble();
    final yield = (area.rentalYield * 18).clamp(0, 100).toDouble();
    final demand = (area.medianIncome / 120 + area.connectivityScore * 0.25)
        .clamp(0, 100)
        .toDouble();
    return [
      ScoreFactor(label: 'Affordability', score: affordability, weight: 0.15),
      ScoreFactor(label: 'Price growth', score: growth, weight: 0.25),
      ScoreFactor(label: 'Population growth', score: population, weight: 0.20),
      ScoreFactor(label: 'Rental yield', score: yield, weight: 0.20),
      ScoreFactor(label: 'Demand signal', score: demand, weight: 0.20),
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

  String _normalise(Object? value) => value
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

}
