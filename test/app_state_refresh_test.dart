import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/data/asset_repository.dart';
import 'package:smart_property_advisor/data/repositories/area_profile_repository.dart';
import 'package:smart_property_advisor/data/repositories/property_repository.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/services/market_trend_cache.dart';

void main() {
  test('startup does not trigger government fetch or upsert', () async {
    final areaRepository = _FakeAreaProfileRepository();
    final propertyRepository = _FakePropertyRepository();
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
    );

    await state.initialise();

    expect(areaRepository.reads, 1);
    expect(propertyRepository.reads, 1);
    expect(areaRepository.upserts, 0);
    expect(propertyRepository.upserts, 0);
    expect(state.areas, hasLength(1));
    expect(state.areas.single.id, 'selangor_gombak');
    expect(state.properties, hasLength(1));
  });

  test('startup restores market cache before cloud area refresh', () async {
    final areaRepository = _FakeAreaProfileRepository();
    final propertyRepository = _FakePropertyRepository();
    final cachedAt = DateTime.utc(2026, 9, 11, 8);
    final cache = _FakeMarketTrendCache(
      entry: MarketTrendCacheEntry(
        areas: const [_cachedMarketArea],
        updatedAt: cachedAt,
      ),
    );
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
      marketTrendCache: cache,
    );

    await state.initialise();

    expect(cache.loads, 1);
    expect(areaRepository.reads, 0);
    expect(propertyRepository.reads, 1);
    expect(state.isUsingMarketTrendCache, isTrue);
    expect(state.areas.single.id, 'kedah_langkawi');
    expect(state.marketTrendCacheUpdatedAt, cachedAt);
  });

  test(
    'fresh cache does not auto refresh when market data is requested',
    () async {
      final areaRepository = _FakeAreaProfileRepository();
      final state = AppState(
        repository: const _FakeAssetRepository(),
        areaProfileRepository: areaRepository,
        propertyRepository: _FakePropertyRepository(),
      );
      state.areas = const [_cachedArea];
      state.marketTrendCacheUpdatedAt = DateTime.now().toUtc();

      await state.ensureInitialMarketData();

      expect(areaRepository.reads, 0);
    },
  );

  test(
    'expired market cache auto-refreshes once from Analysis entry',
    () async {
      final areaRepository = _FakeAreaProfileRepository();
      final cache = _FakeMarketTrendCache(
        entry: MarketTrendCacheEntry(
          areas: const [_cachedMarketArea],
          updatedAt: DateTime.utc(2026, 9, 9),
        ),
      );
      final state = AppState(
        repository: const _FakeAssetRepository(),
        areaProfileRepository: areaRepository,
        propertyRepository: _FakePropertyRepository(),
        marketTrendCache: cache,
      );

      await state.initialise();
      expect(areaRepository.reads, 0);

      await state.ensureInitialMarketData();
      await state.ensureInitialMarketData();

      expect(areaRepository.reads, 1);
      expect(cache.saves, 1);
      expect(state.isUsingCloudAreaProfiles, isTrue);
      expect(
        state.governmentDataRefreshMessage,
        contains('Latest market data reloaded from Supabase'),
      );
    },
  );

  test('expired cache auto refreshes only once per runtime', () async {
    final areaRepository = _OfflineAreaProfileRepository();
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: _FakePropertyRepository(),
    );
    state.areas = const [_cachedArea];
    state.properties = const [_oldProperty];
    state.marketTrendCacheUpdatedAt = DateTime.now().toUtc().subtract(
      const Duration(days: 2),
    );

    await state.ensureInitialMarketData();
    await state.ensureInitialMarketData();

    expect(areaRepository.reads, 1);
    expect(state.areas, const [_cachedArea]);
    expect(state.properties, const [_oldProperty]);
  });

  test('normal latest-data refresh only reads shared Supabase data', () async {
    final areaRepository = _FakeAreaProfileRepository();
    final propertyRepository = _FakePropertyRepository();
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
    );

    final result = await state.refreshLatestData();

    expect(areaRepository.reads, 1);
    expect(propertyRepository.reads, 1);
    expect(areaRepository.upserts, 0);
    expect(propertyRepository.upserts, 0);
    expect(state.isRefreshingLatestData, isFalse);
    expect(state.properties, hasLength(1));
    expect(state.areas.single.id, 'selangor_gombak');
    expect(result.succeeded, isTrue);
    expect(state.latestDataRefreshMessage, contains('Latest data refreshed'));
    expect(state.latestDataRefreshStatus, DataRefreshStatus.success);
  });

  test('explicit latest-data reload only reads Supabase', () async {
    final areaRepository = _FakeAreaProfileRepository();
    final propertyRepository = _FakePropertyRepository();
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
    );

    final result = await state.refreshGovernmentData();

    expect(areaRepository.reads, 1);
    expect(propertyRepository.reads, 1);
    expect(areaRepository.upserts, 0);
    expect(propertyRepository.upserts, 0);
    expect(state.properties, hasLength(1));
    expect(state.isRefreshingGovernmentData, isFalse);
    expect(result.succeeded, isTrue);
    expect(
      state.governmentDataRefreshMessage,
      contains('Latest market data reloaded from Supabase'),
    );
    expect(state.governmentDataRefreshStatus, DataRefreshStatus.success);
  });

  test('failed latest-data reload keeps existing visible data', () async {
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: _FailingAreaProfileRepository(),
      propertyRepository: _FakePropertyRepository(),
    );
    state.areas = const [_oldArea];
    state.properties = const [_oldProperty];

    final result = await state.refreshGovernmentData();

    expect(state.areas, const [_oldArea]);
    expect(state.properties, const [_oldProperty]);
    expect(state.isRefreshingGovernmentData, isFalse);
    expect(result.succeeded, isFalse);
    expect(
      state.governmentDataRefreshMessage,
      'Latest market data could not be reloaded. Cached data is still displayed.',
    );
    expect(state.governmentDataRefreshStatus, DataRefreshStatus.failure);
  });

  test('property refresh failure does not report success', () async {
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: _FakeAreaProfileRepository(),
      propertyRepository: _FailingPropertyRepository(),
    );
    state.areas = const [_oldArea];
    state.properties = const [_oldProperty];

    final result = await state.refreshGovernmentData();

    expect(state.areas, const [_oldArea]);
    expect(state.properties, const [_oldProperty]);
    expect(result.succeeded, isFalse);
    expect(
      result.message,
      'Latest market data could not be reloaded. Cached data is still displayed.',
    );
    expect(state.governmentDataRefreshStatus, DataRefreshStatus.failure);
  });

  test('offline market refresh keeps cached data and timestamp', () async {
    final cachedAt = DateTime.utc(2026, 9, 10, 1);
    final cache = _FakeMarketTrendCache(
      entry: MarketTrendCacheEntry(
        areas: const [_cachedArea],
        updatedAt: cachedAt,
      ),
    );
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: _OfflineAreaProfileRepository(),
      propertyRepository: _FakePropertyRepository(),
      marketTrendCache: cache,
    );
    state.areas = const [_cachedArea];
    state.properties = const [_oldProperty];
    state.marketTrendCacheUpdatedAt = cachedAt;
    state.isUsingMarketTrendCache = true;

    final result = await state.refreshGovernmentData();

    expect(result.succeeded, isFalse);
    expect(
      result.message,
      'Refresh failed: no internet connection. Cached market data is still displayed.',
    );
    expect(state.areas, const [_cachedArea]);
    expect(state.properties, const [_oldProperty]);
    expect(state.marketTrendCacheUpdatedAt, cachedAt);
    expect(cache.saves, 0);
  });

  test('latest-data property failure keeps existing visible data', () async {
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: _FakeAreaProfileRepository(),
      propertyRepository: _FailingPropertyRepository(),
    );
    state.areas = const [_oldArea];
    state.properties = const [_oldProperty];

    final result = await state.refreshLatestData();

    expect(state.areas, const [_oldArea]);
    expect(state.properties, const [_oldProperty]);
    expect(result.succeeded, isFalse);
    expect(state.latestDataRefreshStatus, DataRefreshStatus.failure);
  });
}

const _oldArea = AreaData(
  id: 'old',
  name: 'Old',
  state: 'Selangor',
  population: 1,
  populationGrowth: 0,
  medianIncome: 1,
  safetyScore: 1,
  transportScore: 1,
  schools: 1,
  hospitals: 1,
  averagePricePsf: 1,
  rentalYield: 1,
  priceGrowth: 1,
  priceHistory: [1],
  snapshotDate: '2026',
);

const _cachedArea = AreaData(
  id: 'cached',
  name: 'Cached',
  state: 'Selangor',
  priceHistory: [400000, 420000],
  marketPricePeriods: ['2026 Q1', '2026 Q2'],
  medianResidentialPrice: 420000,
  marketPriceYear: 2026,
);

const _cachedMarketArea = AreaData(
  id: 'kedah_langkawi',
  name: 'Langkawi',
  state: 'Kedah',
  medianResidentialPrice: 315000,
  marketPriceYear: 2026,
  priceHistory: [280000, 315000],
  marketPricePeriods: ['2026 Q1', '2026 Q2'],
  isGovernmentProfile: true,
);

const _oldProperty = Property(
  id: 'old',
  name: 'Old Property',
  areaId: 'old',
  address: 'Old',
  type: 'Apartment',
  tenure: 'Freehold',
  price: 1,
  summary: 'Old',
  facilities: [],
  palette: 1,
);

class _FakeAssetRepository extends AssetRepository {
  const _FakeAssetRepository();

  @override
  Future<List<AreaData>> loadAreas() async {
    return const [
      AreaData(
        id: 'gombak',
        name: 'Gombak',
        state: 'Selangor',
        population: 940000,
        populationGrowth: 0,
        medianIncome: 9000,
        safetyScore: 80,
        transportScore: 70,
        schools: 100,
        hospitals: 8,
        averagePricePsf: 500,
        rentalYield: 3.8,
        priceGrowth: 2.1,
        priceHistory: [480, 490, 500],
        snapshotDate: '2026',
      ),
    ];
  }
}

class _FakeAreaProfileRepository extends AreaProfileRepository {
  int reads = 0;
  int upserts = 0;

  @override
  Future<List<AreaProfile>> getAreaProfiles({int? limit}) async {
    reads += 1;
    return [
      AreaProfile(
        areaId: 'selangor_gombak',
        state: 'Selangor',
        district: 'Gombak',
        population: 942600,
        medianHouseholdIncome: 9134,
        source: 'OpenDOSM; data.gov.my',
        retrievedAt: DateTime.utc(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<int> upsertAreaProfiles(List<AreaProfile> profiles) async {
    upserts += 1;
    throw StateError('normal refresh must not upsert area profiles');
  }
}

class _FailingAreaProfileRepository extends AreaProfileRepository {
  @override
  Future<List<AreaProfile>> getAreaProfiles({int? limit}) async {
    throw StateError('Supabase unavailable');
  }
}

class _OfflineAreaProfileRepository extends AreaProfileRepository {
  int reads = 0;

  @override
  Future<List<AreaProfile>> getAreaProfiles({int? limit}) async {
    reads += 1;
    throw AreaProfileRepositoryException(
      'Failed to load area profiles from Supabase.',
      http.ClientException('SocketException: Failed host lookup'),
      StackTrace.empty,
    );
  }
}

class _FakePropertyRepository extends PropertyRepository {
  int reads = 0;
  int upserts = 0;

  @override
  Future<List<Property>> getProperties(List<AreaData> areas) async {
    reads += 1;
    return const [
      Property(
        id: 'teduh_001',
        name: 'Residensi Gombak',
        areaId: 'selangor_gombak',
        address: 'Gombak, Selangor',
        type: 'Apartment',
        tenure: 'Government housing',
        state: 'Selangor',
        district: 'Gombak',
        price: 300000,
        summary: 'Official housing project information sourced from TEDUH.',
        facilities: ['Selangor'],
        palette: 1,
        source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
        sourceId: '001',
      ),
    ];
  }

  @override
  Future<int> upsertProperties(List<Property> properties) async {
    upserts += 1;
    throw StateError('normal refresh must not upsert properties');
  }
}

class _FailingPropertyRepository extends PropertyRepository {
  @override
  Future<List<Property>> getProperties(List<AreaData> areas) async {
    throw StateError('Supabase unavailable');
  }
}

class _FakeMarketTrendCache extends MarketTrendCache {
  _FakeMarketTrendCache({this.entry});

  MarketTrendCacheEntry? entry;
  int loads = 0;
  int saves = 0;
  List<AreaData> savedAreas = const [];
  DateTime? savedUpdatedAt;

  @override
  Future<MarketTrendCacheEntry?> load() async {
    loads += 1;
    return entry;
  }

  @override
  Future<void> save(List<AreaData> areas, {required DateTime updatedAt}) async {
    saves += 1;
    savedAreas = areas;
    savedUpdatedAt = updatedAt;
    entry = MarketTrendCacheEntry(areas: areas, updatedAt: updatedAt);
  }
}
