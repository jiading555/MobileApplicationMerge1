import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/services/market_trend_cache.dart';

void main() {
  group('MarketTrendCacheEntry freshness', () {
    test('cache age under 24 hours is fresh', () {
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: DateTime.utc(2026, 9, 10, 12, 0),
      );

      expect(entry.isFreshAt(DateTime.utc(2026, 9, 11, 11, 59)), isTrue);
    });

    test('cache exactly 24 hours old is expired', () {
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: DateTime.utc(2026, 9, 10, 12, 0),
      );

      expect(entry.isFreshAt(DateTime.utc(2026, 9, 11, 12, 0)), isFalse);
    });

    test('future cache timestamp is not fresh', () {
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: DateTime.utc(2026, 9, 11, 12, 1),
      );

      expect(entry.isFreshAt(DateTime.utc(2026, 9, 11, 12, 0)), isFalse);
    });
  });

  test('AreaData cache serialization retains NAPIC market fields', () {
    final marketRetrievedAt = DateTime.utc(2026, 9, 9, 3, 4, 5);
    final original = AreaData(
      id: 'selangor_gombak',
      name: 'Gombak',
      state: 'Selangor',
      priceHistory: const [410000, 425000, 440000],
      marketPricePeriods: const ['2025 Q4', '2026 Q1', '2026 Q2'],
      marketPriceHistoryByType: const {
        'Terrace': [500000, 515000],
        'Apartment': [310000, 325000],
      },
      marketPricePeriodsByType: const {
        'Terrace': ['2026 Q1', '2026 Q2'],
        'Apartment': ['2026 Q1', '2026 Q2'],
      },
      marketAreaPriceHistoryByType: const {
        'Bandar Gombak': {
          'Terrace': [520000, 535000],
          'Apartment': [330000, 340000],
        },
      },
      marketAreaPricePeriodsByType: const {
        'Bandar Gombak': {
          'Terrace': ['2026 Q1', '2026 Q2'],
          'Apartment': ['2026 Q1', '2026 Q2'],
        },
      },
      medianResidentialPrice: 440000,
      marketPriceYear: 2026,
      transactionCount: 1234,
      previousTransactionCount: 1175,
      transactionValueMillion: 812.5,
      previousTransactionValueMillion: 760.25,
      marketPeriod: '2026 Q2',
      marketRetrievedAt: marketRetrievedAt,
    );

    final restored = AreaData.fromCacheJson(original.toCacheJson());

    expect(restored.priceHistory, [410000, 425000, 440000]);
    expect(restored.marketPricePeriods, ['2025 Q4', '2026 Q1', '2026 Q2']);
    expect(restored.marketPriceHistoryByType, {
      'Terrace': [500000, 515000],
      'Apartment': [310000, 325000],
    });
    expect(restored.marketPricePeriodsByType, {
      'Terrace': ['2026 Q1', '2026 Q2'],
      'Apartment': ['2026 Q1', '2026 Q2'],
    });
    expect(restored.marketAreaPriceHistoryByType, {
      'Bandar Gombak': {
        'Terrace': [520000, 535000],
        'Apartment': [330000, 340000],
      },
    });
    expect(restored.marketAreaPricePeriodsByType, {
      'Bandar Gombak': {
        'Terrace': ['2026 Q1', '2026 Q2'],
        'Apartment': ['2026 Q1', '2026 Q2'],
      },
    });
    expect(restored.medianResidentialPrice, 440000);
    expect(restored.marketPriceYear, 2026);
    expect(restored.transactionCount, 1234);
    expect(restored.previousTransactionCount, 1175);
    expect(restored.transactionValueMillion, 812.5);
    expect(restored.previousTransactionValueMillion, 760.25);
    expect(restored.marketPeriod, '2026 Q2');
    expect(restored.marketRetrievedAt, marketRetrievedAt);
  });
}
