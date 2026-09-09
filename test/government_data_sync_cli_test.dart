import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/services/government_data_sync.dart';
import 'package:smart_property_advisor/services/open_data_service.dart';
import 'package:smart_property_advisor/services/teduh_service.dart';

void main() {
  test('missing sync environment variables fail safely', () {
    expect(
      () => GovernmentDataSyncEnvironment.fromMap(const {}),
      throwsA(
        isA<GovernmentDataSyncConfigurationException>().having(
          (error) => error.toString(),
          'message',
          'SUPABASE_URL is required.',
        ),
      ),
    );

    expect(
      () => GovernmentDataSyncEnvironment.fromMap(const {
        'SUPABASE_URL': 'https://example.supabase.co',
      }),
      throwsA(
        isA<GovernmentDataSyncConfigurationException>().having(
          (error) => error.toString(),
          'message',
          'SUPABASE_SERVICE_ROLE_KEY is required.',
        ),
      ),
    );
  });

  test(
    'Supabase REST area profile upsert request is constructed correctly',
    () async {
      http.Request? capturedRequest;
      String? capturedBody;
      final client = MockClient((request) async {
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response('', 201);
      });
      final restClient = SupabaseGovernmentDataRestClient(
        environment: const GovernmentDataSyncEnvironment(
          supabaseUrl: 'https://example.supabase.co',
          serviceRoleKey: 'test-maintenance-key',
        ),
        client: client,
      );

      final count = await restClient.upsertAreaProfiles([
        AreaProfile(
          areaId: 'selangor_gombak',
          state: 'Selangor',
          district: 'Gombak',
          population: 942600,
          retrievedAt: DateTime.utc(2026, 9, 9),
        ),
      ]);

      expect(count, 1);
      expect(
        capturedRequest!.url.toString(),
        'https://example.supabase.co/rest/v1/area_profiles?on_conflict=area_id',
      );
      expect(capturedRequest!.headers['apikey'], 'test-maintenance-key');
      expect(
        capturedRequest!.headers['Authorization'],
        'Bearer test-maintenance-key',
      );
      expect(
        capturedRequest!.headers['Prefer'],
        'resolution=merge-duplicates,return=minimal',
      );
      final body = jsonDecode(capturedBody!) as List<dynamic>;
      expect(body.single['area_id'], 'selangor_gombak');
      expect(body.single['updated_at'], isNotNull);
    },
  );

  test(
    'Supabase REST property upsert request uses source_id conflict key',
    () async {
      http.Request? capturedRequest;
      String? capturedBody;
      final client = MockClient((request) async {
        capturedRequest = request;
        capturedBody = request.body;
        return http.Response('', 204);
      });
      final restClient = SupabaseGovernmentDataRestClient(
        environment: const GovernmentDataSyncEnvironment(
          supabaseUrl: 'https://example.supabase.co/',
          serviceRoleKey: 'test-maintenance-key',
        ),
        client: client,
      );

      final count = await restClient.upsertProperties([
        const Property(
          id: 'teduh_001',
          name: 'Residensi Gombak',
          areaId: 'selangor_gombak',
          address: 'Gombak, Selangor',
          type: 'Public housing',
          tenure: 'Tenure not available',
          state: 'Selangor',
          district: 'Gombak',
          price: 300000,
          summary: 'Public housing/project record from TEDUH.',
          facilities: [],
          palette: 1,
          sourceId: '001',
          scheme: 'PR1MA Homes',
          unitTypes: ['APARTMEN'],
        ),
      ]);

      expect(count, 1);
      expect(
        capturedRequest!.url.toString(),
        'https://example.supabase.co/rest/v1/properties?on_conflict=source_id',
      );
      final body = jsonDecode(capturedBody!) as List<dynamic>;
      expect(body.single['source_id'], '001');
      expect(body.single['property_type'], isNull);
      expect(body.single.containsKey('property_type'), isTrue);
      expect(body.single['unit_types'], ['APARTMEN']);
      expect(body.single['scheme'], 'PR1MA Homes');
      expect(body.single['updated_at'], isNotNull);
    },
  );

  test('Supabase payload explicitly overwrites bad property_type with null', () async {
    String? capturedBody;
    final client = MockClient((request) async {
      capturedBody = request.body;
      return http.Response('', 204);
    });
    final restClient = SupabaseGovernmentDataRestClient(
      environment: const GovernmentDataSyncEnvironment(
        supabaseUrl: 'https://example.supabase.co',
        serviceRoleKey: 'test-maintenance-key',
      ),
      client: client,
    );

    await restClient.upsertProperties([
      Property.fromTeduhJson(
        {
          'source_id': 'PPAM_1',
          'project_name': 'Taman Mixed',
          'property_type': null,
          'unit_types': ['RUMAH TERES', 'RUMAH BERKEMBAR'],
        },
        areaId: 'unknown',
        palette: 0,
      ),
    ]);

    final body = jsonDecode(capturedBody!) as List<dynamic>;
    expect(body.single.containsKey('property_type'), isTrue);
    expect(body.single['property_type'], isNull);
  });

  test('full dynamic AreaProfile list reaches REST upsert layer', () async {
    final postedTables = <String, List<dynamic>>{};
    final client = MockClient((request) async {
      final table = request.url.pathSegments.last;
      postedTables[table] = jsonDecode(request.body) as List<dynamic>;
      return http.Response('', 204);
    });
    final runner = GovernmentDataSyncRunner(
      openDataService: _ManyDistrictOpenDataService(),
      teduhService: _NoopTeduhService(),
      supabaseClient: SupabaseGovernmentDataRestClient(
        environment: const GovernmentDataSyncEnvironment(
          supabaseUrl: 'https://example.supabase.co',
          serviceRoleKey: 'test-maintenance-key',
        ),
        client: client,
      ),
    );

    final result = await runner.run();

    expect(result.areaProfiles, hasLength(7));
    expect(result.upsertedAreaProfiles, 7);
    expect(postedTables['area_profiles'], hasLength(7));
    expect(
      postedTables['area_profiles']!
          .map((row) => (row as Map<String, dynamic>)['area_id']),
      containsAll([
        'selangor_petaling',
        'selangor_klang',
        'johor_johor_bahru',
      ]),
    );
  });
}

class _ManyDistrictOpenDataService extends OpenDataService {
  @override
  Future<List<AreaProfile>> fetchAreaProfiles() async {
    return const [
      AreaProfile(
        areaId: 'selangor_petaling',
        state: 'Selangor',
        district: 'Petaling',
      ),
      AreaProfile(
        areaId: 'selangor_gombak',
        state: 'Selangor',
        district: 'Gombak',
      ),
      AreaProfile(
        areaId: 'selangor_klang',
        state: 'Selangor',
        district: 'Klang',
      ),
      AreaProfile(
        areaId: 'selangor_ulu_langat',
        state: 'Selangor',
        district: 'Ulu Langat',
      ),
      AreaProfile(
        areaId: 'johor_johor_bahru',
        state: 'Johor',
        district: 'Johor Bahru',
      ),
      AreaProfile(
        areaId: 'pulau_pinang_timur_laut',
        state: 'Pulau Pinang',
        district: 'Timur Laut',
      ),
      AreaProfile(areaId: 'perak_kinta', state: 'Perak', district: 'Kinta'),
    ];
  }
}

class _NoopTeduhService extends TeduhService {
  @override
  Future<List<Property>> fetchProjects({String? scheme}) async {
    return const [];
  }
}
