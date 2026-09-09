import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/data/asset_repository.dart';
import 'package:smart_property_advisor/data/repositories/area_profile_repository.dart';
import 'package:smart_property_advisor/data/repositories/property_repository.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';

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

  test('normal latest-data refresh only reads shared Supabase data', () async {
    final areaRepository = _FakeAreaProfileRepository();
    final propertyRepository = _FakePropertyRepository();
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
    );

    await state.refreshLatestData();

    expect(areaRepository.reads, 1);
    expect(propertyRepository.reads, 1);
    expect(areaRepository.upserts, 0);
    expect(propertyRepository.upserts, 0);
    expect(state.isRefreshingLatestData, isFalse);
    expect(state.properties, hasLength(1));
    expect(state.areas.single.id, 'selangor_gombak');
    expect(state.latestDataRefreshMessage, contains('Latest data refreshed'));
  });

  test('explicit latest-data reload only reads Supabase', () async {
    final areaRepository = _FakeAreaProfileRepository();
    final propertyRepository = _FakePropertyRepository();
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
    );

    await state.refreshGovernmentData();

    expect(areaRepository.reads, 1);
    expect(propertyRepository.reads, 1);
    expect(areaRepository.upserts, 0);
    expect(propertyRepository.upserts, 0);
    expect(state.properties, hasLength(1));
    expect(state.isRefreshingGovernmentData, isFalse);
    expect(
      state.governmentDataRefreshMessage,
      contains('Latest data reloaded'),
    );
  });

  test('failed latest-data reload keeps existing visible data', () async {
    final state = AppState(
      repository: const _FakeAssetRepository(),
      areaProfileRepository: _FailingAreaProfileRepository(),
      propertyRepository: _FakePropertyRepository(),
    );
    state.areas = const [_oldArea];
    state.properties = const [_oldProperty];

    await state.refreshGovernmentData();

    expect(state.areas, const [_oldArea]);
    expect(state.properties, const [_oldProperty]);
    expect(state.isRefreshingGovernmentData, isFalse);
    expect(
      state.governmentDataRefreshMessage,
      contains('Latest data reload failed'),
    );
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
  connectivityScore: 1,
  transportScore: 1,
  schools: 1,
  hospitals: 1,
  averagePricePsf: 1,
  rentalYield: 1,
  priceGrowth: 1,
  priceHistory: [1],
  snapshotDate: '2026',
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
        connectivityScore: 70,
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
        summary: 'Public housing/project record from TEDUH.',
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
