import '../models/area_data.dart';

class MarketTrendCacheEntry {
  const MarketTrendCacheEntry({required this.areas, required this.updatedAt});

  final List<AreaData> areas;
  final DateTime updatedAt;

  bool isFreshAt(DateTime now) {
    final age = now.toUtc().difference(updatedAt.toUtc());
    return !age.isNegative && age < const Duration(days: 1);
  }
}

class MarketTrendCache {
  Future<MarketTrendCacheEntry?> load() async => null;

  Future<void> save(
    List<AreaData> areas, {
    required DateTime updatedAt,
  }) async {}
}
