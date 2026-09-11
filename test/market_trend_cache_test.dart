import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/services/market_trend_cache.dart';

void main() {
  test('market cache is fresh for less than one day', () {
    final entry = MarketTrendCacheEntry(
      areas: const [],
      updatedAt: DateTime.utc(2026, 9, 10, 12),
    );

    expect(entry.isFreshAt(DateTime.utc(2026, 9, 11, 11, 59)), isTrue);
    expect(entry.isFreshAt(DateTime.utc(2026, 9, 11, 12)), isFalse);
    expect(entry.isFreshAt(DateTime.utc(2026, 9, 10, 11)), isFalse);
  });

  test('NAPIC market fields survive cache serialization', () {
    final retrievedAt = DateTime.utc(2026, 9, 10);
    final source = AreaData(
      id: 'johor_tangkak',
      name: 'Tangkak',
      state: 'Johor',
      population: 170000,
      populationGrowth: 1.2,
      medianIncome: 6100,
      safetyScore: 73,
      transportScore: 48,
      schools: 42,
      hospitals: 2,
      hospitalBeds: 120,
      transportStopCount: 36,
      priceHistory: const [320000, 335000],
      marketPricePeriods: const ['2025', '2026'],
      marketPriceHistoryByType: const {
        'Terrace House': [310000, 330000],
      },
      marketPricePeriodsByType: const {
        'Terrace House': ['2025', '2026'],
      },
      marketAreaPriceHistoryByType: const {
        'Tangkak Town': {
          'Terrace House': [300000, 325000],
        },
      },
      marketAreaPricePeriodsByType: const {
        'Tangkak Town': {
          'Terrace House': ['2025', '2026'],
        },
      },
      medianResidentialPrice: 335000,
      marketPriceYear: 2026,
      transactionCount: 100,
      previousTransactionCount: 80,
      transactionValueMillion: 42,
      previousTransactionValueMillion: 35,
      marketPeriod: 'Q1 2026',
      marketSourceUrl: 'https://napic.jpph.gov.my',
      marketRetrievedAt: retrievedAt,
    );

    final restored = AreaData.fromCacheJson(source.toCacheJson());

    expect(restored.priceHistory, source.priceHistory);
    expect(restored.marketPricePeriods, source.marketPricePeriods);
    expect(
      restored.marketPriceHistoryByType,
      source.marketPriceHistoryByType,
    );
    expect(
      restored.marketAreaPriceHistoryByType,
      source.marketAreaPriceHistoryByType,
    );
    expect(restored.medianResidentialPrice, 335000);
    expect(restored.transactionCount, 100);
    expect(restored.previousTransactionCount, 80);
    expect(restored.transactionValueMillion, 42);
    expect(restored.previousTransactionValueMillion, 35);
    expect(restored.marketPeriod, 'Q1 2026');
    expect(restored.marketRetrievedAt, retrievedAt);
  });
}
