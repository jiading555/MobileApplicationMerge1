import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/models/user_preferences.dart';
import 'package:smart_property_advisor/services/recommendation_service.dart';

void main() {
  group('RecommendationService', () {
    const service = RecommendationService();

    test('scoreProperty scores properties excluded by advisor filters', () {
      final recommendation = service.scoreProperty(
        property: _huluProperty,
        areas: const [_huluTerengganuArea],
        preferences: const UserPreferences(propertyType: 'Apartment / Flat'),
      );

      final ranked = service.rank(
        properties: const [_huluProperty],
        areas: const [_huluTerengganuArea],
        preferences: const UserPreferences(propertyType: 'Apartment / Flat'),
      );

      expect(ranked, isEmpty);
      expect(recommendation, isNotNull);
      expect(recommendation!.score.round(), 78);
    });

    test('ranked recommendations keep the same scoring behaviour', () {
      final preferences = const UserPreferences();
      final directRecommendation = service.scoreProperty(
        property: _huluProperty,
        areas: const [_huluTerengganuArea],
        preferences: preferences,
      );

      final ranked = service.rank(
        properties: const [_huluProperty],
        areas: const [_huluTerengganuArea],
        preferences: preferences,
      );

      expect(ranked, hasLength(1));
      expect(ranked.single.score, directRecommendation!.score);
      expect(
        ranked.single.factors.map(
          (factor) => (factor.label, factor.score, factor.weight),
        ),
        directRecommendation.factors.map(
          (factor) => (factor.label, factor.score, factor.weight),
        ),
      );
      expect(ranked.single.reasons, directRecommendation.reasons);
      expect(ranked.single.cautions, directRecommendation.cautions);
    });
  });
}

const _huluProperty = Property(
  id: 'teduh_service_hulu',
  name: 'Hulu Terengganu Residence',
  areaId: 'terengganu_hulu_terengganu',
  address: 'Hulu Terengganu, Terengganu',
  type: 'Rumah Teres 1 Tingkat',
  tenure: '',
  verifiedPropertyType: 'Rumah Teres 1 Tingkat',
  state: 'Terengganu',
  district: 'Hulu Terengganu',
  price: 300000,
  summary: 'Official housing project information sourced from TEDUH.',
  facilities: [],
  palette: 0,
  source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
);

const _huluTerengganuArea = AreaData(
  id: 'terengganu_hulu_terengganu',
  name: 'Hulu Terengganu',
  state: 'Terengganu',
  population: 75000,
  medianIncome: 5090,
  safetyScore: 94,
  transportScore: 80,
  schools: 10,
  priceGrowth: 28.1,
  snapshotDate: '2025',
  source: 'OpenDOSM; data.gov.my',
  isGovernmentProfile: true,
);
