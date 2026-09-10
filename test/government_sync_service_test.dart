import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/data/repositories/area_profile_repository.dart';
import 'package:smart_property_advisor/data/repositories/property_repository.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/services/government_sync_service.dart';
import 'package:smart_property_advisor/services/open_data_service.dart';
import 'package:smart_property_advisor/services/teduh_service.dart';

void main() {
  test('explicit government sync fetches and upserts shared tables', () async {
    final openDataService = _FakeOpenDataService();
    final teduhService = _FakeTeduhService();
    final areaRepository = _SyncAreaProfileRepository();
    final propertyRepository = _SyncPropertyRepository();
    final syncService = GovernmentSyncService(
      openDataService: openDataService,
      teduhService: teduhService,
      areaProfileRepository: areaRepository,
      propertyRepository: propertyRepository,
    );

    final result = await syncService.sync();

    expect(openDataService.fetches, 1);
    expect(teduhService.fetches, 1);
    expect(areaRepository.upserts, 1);
    expect(propertyRepository.upserts, 1);
    expect(result.upsertedAreaProfiles, 1);
    expect(result.upsertedTeduhProjects, 1);
    expect(
      areaRepository.lastProfiles.single.areaId,
      'pulau_pinang_timur_laut',
    );
  });

  test(
    'null district property stays unmapped instead of random state area',
    () {
      final areaId = PropertyRepository.resolveAreaIdForRow(
        const {'state': 'Selangor', 'district': null},
        const [
          AreaData(
            id: 'selangor_petaling',
            name: 'Petaling',
            state: 'Selangor',
          ),
          AreaData(id: 'selangor_klang', name: 'Klang', state: 'Selangor'),
        ],
      );

      expect(areaId, 'unknown');
    },
  );

  test('exact canonical state and district still map to an area', () {
    final areaId = PropertyRepository.resolveAreaIdForRow(
      const {'state': 'Selangor', 'district': 'Klang'},
      const [
        AreaData(id: 'selangor_petaling', name: 'Petaling', state: 'Selangor'),
        AreaData(id: 'selangor_klang', name: 'Klang', state: 'Selangor'),
      ],
    );

    expect(areaId, 'selangor_klang');
  });
}

class _FakeOpenDataService extends OpenDataService {
  int fetches = 0;

  @override
  Future<List<AreaProfile>> fetchAreaProfiles() async {
    fetches += 1;
    return const [
      AreaProfile(
        areaId: 'penang_timur_laut',
        state: 'Penang',
        district: 'Timur Laut',
        population: 565900,
        source: 'OpenDOSM',
      ),
      AreaProfile(
        areaId: 'pulau_pinang_timur_laut',
        state: 'Pulau Pinang',
        district: 'Timur Laut',
        medianHouseholdIncome: 7745,
        source: 'data.gov.my',
      ),
    ];
  }
}

class _FakeTeduhService extends TeduhService {
  int fetches = 0;

  @override
  Future<List<Property>> fetchProjects({String? scheme}) async {
    fetches += 1;
    return const [
      Property(
        id: 'teduh_123',
        name: 'Residensi Timur Laut',
        areaId: 'pulau_pinang_timur_laut',
        address: 'Timur Laut, Pulau Pinang',
        type: 'Apartment',
        tenure: 'Government housing',
        state: 'Pulau Pinang',
        district: 'Timur Laut',
        price: 300000,
        summary: 'Official housing project information sourced from TEDUH.',
        facilities: ['Pulau Pinang'],
        palette: 1,
        source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
        sourceId: '123',
      ),
    ];
  }
}

class _SyncAreaProfileRepository extends AreaProfileRepository {
  int upserts = 0;
  List<AreaProfile> lastProfiles = const [];

  @override
  Future<int> upsertAreaProfiles(List<AreaProfile> profiles) async {
    upserts += 1;
    lastProfiles = profiles;
    return profiles.length;
  }
}

class _SyncPropertyRepository extends PropertyRepository {
  int upserts = 0;

  @override
  Future<int> upsertProperties(List<Property> properties) async {
    upserts += 1;
    return properties.length;
  }

  @override
  Future<List<Property>> getProperties(List<AreaData> areas) async {
    return const [];
  }
}
