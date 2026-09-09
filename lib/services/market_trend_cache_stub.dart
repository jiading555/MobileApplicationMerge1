import '../models/area_data.dart';

class MarketTrendCacheEntry {
  const MarketTrendCacheEntry({
    required this.areas,
    required this.updatedAt,
  });

  final List<AreaData> areas;
  final DateTime updatedAt;
}

class MarketTrendCache {
  Future<MarketTrendCacheEntry?> load() async => null;

  Future<void> save(
    List<AreaData> areas, {
    required DateTime updatedAt,
  }) async {}
}
