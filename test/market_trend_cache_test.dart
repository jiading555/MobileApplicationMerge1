import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/services/market_trend_cache.dart';

void main() {
  group('MarketTrendCacheEntry freshness', () {
    test('cache age under 24 hours is fresh', () {
      final now = DateTime.utc(2026, 9, 11, 12);
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: now.subtract(const Duration(hours: 23, minutes: 59)),
      );

      expect(entry.isFreshAt(now), isTrue);
    });

    test('cache exactly 24 hours old is expired', () {
      final now = DateTime.utc(2026, 9, 11, 12);
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      expect(entry.isFreshAt(now), isFalse);
    });

    test('future cache timestamp is not fresh', () {
      final now = DateTime.utc(2026, 9, 11, 12);
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: now.add(const Duration(minutes: 1)),
      );

      expect(entry.isFreshAt(now), isFalse);
    });
  });

  test('AreaData cache JSON preserves NAPIC market fields', () {
    final marketRetrievedAt = DateTime.utc(2026, 9, 9, 3, 4, 5);
    final area = AreaData(
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
      isGovernmentProfile: true,
    );

    final restored = AreaData.fromCacheJson(area.toCacheJson());

    expect(restored.priceHistory, area.priceHistory);
    expect(restored.marketPricePeriods, area.marketPricePeriods);
    expect(restored.marketPriceHistoryByType, area.marketPriceHistoryByType);
    expect(restored.marketPricePeriodsByType, area.marketPricePeriodsByType);
    expect(
      restored.marketAreaPriceHistoryByType,
      area.marketAreaPriceHistoryByType,
    );
    expect(
      restored.marketAreaPricePeriodsByType,
      area.marketAreaPricePeriodsByType,
    );
    expect(restored.medianResidentialPrice, area.medianResidentialPrice);
    expect(restored.marketPriceYear, area.marketPriceYear);
    expect(restored.transactionCount, area.transactionCount);
    expect(restored.previousTransactionCount, area.previousTransactionCount);
    expect(restored.transactionValueMillion, area.transactionValueMillion);
    expect(
      restored.previousTransactionValueMillion,
      area.previousTransactionValueMillion,
    );
    expect(restored.marketPeriod, area.marketPeriod);
    expect(restored.marketRetrievedAt, marketRetrievedAt);
    expect(restored.isGovernmentProfile, isTrue);
  });
}
