import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/services/market_trend_cache.dart';

void main() {
  group('MarketTrendCacheEntry freshness', () {
    test('cache age below 24 hours is fresh', () {
      final now = DateTime.utc(2026, 9, 11, 12);
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: now.subtract(const Duration(hours: 23, minutes: 59)),
      );

      expect(entry.isFreshAt(now), isTrue);
    });

    test('cache age exactly 24 hours is stale', () {
      final now = DateTime.utc(2026, 9, 11, 12);
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      expect(entry.isFreshAt(now), isFalse);
    });

    test('future cache timestamp is stale', () {
      final now = DateTime.utc(2026, 9, 11, 12);
      final entry = MarketTrendCacheEntry(
        areas: const [],
        updatedAt: now.add(const Duration(minutes: 1)),
      );

      expect(entry.isFreshAt(now), isFalse);
    });
  });

  test('AreaData cache JSON preserves NAPIC market fields', () {
    final area = AreaData(
      id: 'kedah_langkawi',
      name: 'Langkawi',
      state: 'Kedah',
      priceHistory: const [280000, 300000, 315000],
      marketPricePeriods: const ['2025 Q4', '2026 Q1', '2026 Q2'],
      marketPriceHistoryByType: const {
        'Terrace House': [300000, 320000],
        'Condominium': [420000, 430000],
      },
      marketPricePeriodsByType: const {
        'Terrace House': ['2026 Q1', '2026 Q2'],
        'Condominium': ['2026 Q1', '2026 Q2'],
      },
      marketAreaPriceHistoryByType: const {
        'Mukim Kuah': {
          'Terrace House': [290000, 305000],
          'Condominium': [410000, 425000],
        },
        'Padang Matsirat': {
          'Terrace House': [260000, 275000],
        },
      },
      marketAreaPricePeriodsByType: const {
        'Mukim Kuah': {
          'Terrace House': ['2026 Q1', '2026 Q2'],
          'Condominium': ['2026 Q1', '2026 Q2'],
        },
        'Padang Matsirat': {
          'Terrace House': ['2026 Q1', '2026 Q2'],
        },
      },
      medianResidentialPrice: 315000,
      marketPriceYear: 2026,
      transactionCount: 128,
      previousTransactionCount: 111,
      transactionValueMillion: 48.5,
      previousTransactionValueMillion: 42.25,
      marketPeriod: '2026 Q2',
      marketRetrievedAt: DateTime.utc(2026, 9, 10, 3, 4, 5),
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
    expect(restored.marketRetrievedAt, area.marketRetrievedAt);
  });
}
