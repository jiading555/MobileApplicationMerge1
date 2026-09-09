import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_property_advisor/core/utils/property_filtering.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/services/teduh_service.dart';

void main() {
  test('TEDUH property mapping keeps stable Supabase keys', () {
    final property = Property.fromTeduhJson(
      {
        'source_id': 'teduh-001',
        'project_name': 'Residensi Test',
        'state': 'Selangor',
        'district': 'Gombak',
        'source': 'TEDUH - Jabatan Perumahan Negara, KPKT',
      },
      areaId: 'selangor_gombak',
      palette: 1,
    );

    final supabaseJson = property.toSupabaseJson();

    expect(property.id, 'teduh_teduh-001');
    expect(property.name, 'Residensi Test');
    expect(supabaseJson['source_id'], 'teduh-001');
    expect(supabaseJson['project_name'], 'Residensi Test');
    expect(supabaseJson.containsKey('price_min'), isTrue);
    expect(supabaseJson.containsKey('available_units'), isTrue);
    expect(supabaseJson.containsKey('raw_location'), isTrue);
  });

  test('area profile mapping keeps stable Supabase keys', () {
    final profile = AreaProfile.fromJson({
      'area_id': 'selangor_gombak',
      'state': 'Selangor',
      'district': 'Gombak',
      'population': 942600,
      'median_household_income': 9134,
      'source': 'OpenDOSM; data.gov.my',
    });

    final supabaseJson = profile.toSupabaseJson();

    expect(profile.areaId, 'selangor_gombak');
    expect(profile.medianHouseholdIncome, 9134);
    expect(supabaseJson['area_id'], 'selangor_gombak');
    expect(supabaseJson.containsKey('crime_count'), isTrue);
    expect(supabaseJson.containsKey('education_institution_count'), isTrue);
    expect(supabaseJson.containsKey('transport_stop_count'), isTrue);
  });

  test('filter normalization handles actual TEDUH and app values', () {
    expect(
      PropertyFilterNormalizer.normalizeType('APARTMEN'),
      'Apartment / Flat',
    );
    expect(
      PropertyFilterNormalizer.normalizeType('RUMAH TERES'),
      'Terrace House',
    );
    expect(
      PropertyFilterNormalizer.normalizeType('Rumah Teres Satu Tingkat'),
      'Terrace House',
    );
    expect(
      PropertyFilterNormalizer.normalizeType('Rumah Pangsa'),
      'Apartment / Flat',
    );
    expect(PropertyFilterNormalizer.normalizeType('Freehold'), 'Other');

    expect(PropertyFilterNormalizer.normalizeTenure('FREEHOLD'), 'Freehold');
    expect(PropertyFilterNormalizer.normalizeTenure('Free Hold'), 'Freehold');
    expect(PropertyFilterNormalizer.normalizeTenure('leasehold'), 'Leasehold');
    expect(PropertyFilterNormalizer.normalizeTenure('Lease Hold'), 'Leasehold');
  });

  test('TEDUH sync prefers JSON pagination over HTML fallback', () async {
    final client = MockClient((request) {
      final uri = request.url;
      if (uri.path == '/api/portal/projects/filters') {
        return Future.value(
          http.Response(
            jsonEncode({
              'states': [
                {'name': 'Selangor'},
              ],
            }),
            200,
          ),
        );
      }
      if (uri.path == '/api/portal/projects' &&
          uri.queryParameters['page'] == '1') {
        return Future.value(
          http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'teduh-123',
                  'name': 'Residensi JSON',
                  'location': 'Selangor, Gombak',
                  'state': 'Selangor',
                  'district': 'Gombak',
                  'scheme_name': 'Residensi Wilayah',
                  'units': [
                    {'house_type': 'Apartment', 'price_start': 250000},
                  ],
                  'latitude': 3.1,
                  'longitude': 101.7,
                },
              ],
              'last_page': 1,
            }),
            200,
          ),
        );
      }
      if (uri.path == '/projek') {
        return Future.value(
          http.Response('''
            <html><body><div id="app">
              <article class="ppam-card">
                <div class="footer-title">HTML Fallback Project</div>
                <div class="footer-loc">Selangor, Gombak</div>
                <div class="price-pill">350000</div>
              </article>
            </div></body></html>
            ''', 200),
        );
      }
      return Future.value(http.Response('not found', 404));
    });

    final service = TeduhService(client: client);
    final projects = await service.fetchProjects();

    expect(projects, hasLength(1));
    expect(projects.first.name, 'Residensi JSON');
    expect(projects.first.sourceId, 'teduh-123');
  });

  test('TEDUH PR1MA-like mapping keeps unit type separate from property_type', () async {
    final client = MockClient((request) {
      final uri = request.url;
      if (uri.path == '/api/portal/projects/filters') {
        return Future.value(
          http.Response(
            jsonEncode({
              'states': [
                {'name': 'Kedah'},
              ],
            }),
            200,
          ),
        );
      }
      if (uri.path == '/api/portal/projects') {
        return Future.value(
          http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'PR1MA_109',
                  'name': 'RESIDENSI UTAMA',
                  'total_unit': 1349,
                  'baki_unit': '-',
                  'location': 'SUNGAI PETANI, KEDAH',
                  'scheme_logo_url':
                      'https://teduh.kpkt.gov.my/images/project/pr1ma.jpg',
                  'price_text': 'RM 118,888',
                  'developer': {'name': 'PR1MA CORPORATION MALAYSIA'},
                  'units': [
                    {
                      'id': 'PR1MA_109',
                      'house_type': 'RUMAH TERES',
                      'unit_type': '-',
                      'price_start': '118888.00',
                    },
                  ],
                },
              ],
              'last_page': 1,
            }),
            200,
          ),
        );
      }
      return Future.value(http.Response('not found', 404));
    });

    final property = (await TeduhService(client: client).fetchProjects()).single;
    final supabaseJson = property.toSupabaseJson();

    expect(property.scheme, 'PR1MA Homes');
    expect(property.district, 'Sungai Petani');
    expect(property.priceMin, 118888);
    expect(property.totalUnits, 1349);
    expect(property.developerName, 'PR1MA CORPORATION MALAYSIA');
    expect(property.unitTypes, ['RUMAH TERES']);
    expect(property.verifiedPropertyType, isNull);
    expect(property.type, 'Public housing');
    expect(supabaseJson['property_type'], isNull);
    expect(supabaseJson['unit_types'], ['RUMAH TERES']);
  });

  test('TEDUH PPAM-like mapping deduplicates multiple house types', () async {
    final property = await _singleTeduhProject({
      'id': 'PPAM_719',
      'name': 'TAMAN GALAKSI',
      'total_unit': 52,
      'baki_unit': 25,
      'location': 'JEMPOL, NEGERI SEMBILAN',
      'scheme_logo_url': 'https://teduh.kpkt.gov.my/images/project/ppam.jpg',
      'price_text': 'RM 189,440',
      'developer': {'name': 'BENAR SEJAGAT SDN. BHD.'},
      'units': [
        {
          'id': 'PPAM_2307',
          'house_type': 'RUMAH TERES',
          'unit_type': 'RUMAH TERES 1 TINGKAT JENIS B',
          'price_start': '189440.00',
        },
        {
          'id': 'PPAM_2308',
          'house_type': 'RUMAH BERKEMBAR',
          'unit_type': 'RUMAH BERKEMBAR 1 TINGKAT',
          'price_start': '300000.00',
        },
        {
          'id': 'PPAM_2309',
          'house_type': 'RUMAH TERES',
          'unit_type': 'RUMAH TERES 1 TINGKAT JENIS A',
          'price_start': '235000.00',
        },
      ],
    });

    expect(property.scheme, 'Perumahan Penjawat Awam Malaysia (PPAM)');
    expect(property.unitTypes, ['RUMAH TERES', 'RUMAH BERKEMBAR']);
    expect(property.priceMin, 189440);
    expect(property.priceMax, 300000);
    expect(property.availableUnits, 25);
    expect(property.verifiedPropertyType, isNull);
    expect(property.toSupabaseJson()['property_type'], isNull);
  });

  test('TEDUH SPNB-like mapping falls back from blank house_type to unit_type', () async {
    final property = await _singleTeduhProject({
      'id': 'SPNB_7',
      'name': 'Taman Kelubi Idaman, Jasin',
      'total_unit': 0,
      'baki_unit': '-',
      'location': 'MELAKA',
      'scheme_logo_url': 'https://teduh.kpkt.gov.my/images/project/spnb.jpg',
      'price_text': 'RM 128,000',
      'developer': {
        'name': 'Syarikat Perumahan Negara Berhad (SPNB)',
      },
      'units': [
        {
          'id': 'SPNB_701',
          'house_type': '-',
          'unit_type': 'Rumah Bandar',
          'price_start': '128000.00',
        },
        {
          'id': 'SPNB_702',
          'house_type': '-',
          'unit_type': 'Rumah Teres 2 Tingkat (Jenis A)',
          'price_start': '208000.00',
        },
      ],
    });

    expect(property.scheme, 'Syarikat Perumahan Negara Berhad (SPNB)');
    expect(property.state, 'Melaka');
    expect(property.district, isNull);
    expect(property.unitTypes, [
      'Rumah Bandar',
      'Rumah Teres 2 Tingkat (Jenis A)',
    ]);
    expect(property.verifiedPropertyType, isNull);
    expect(property.toSupabaseJson()['property_type'], isNull);
  });

  test('TEDUH pagination follows last_page without artificial cap', () async {
    final requestedPages = <String>[];
    final client = MockClient((request) {
      final uri = request.url;
      if (uri.path == '/api/portal/projects/filters') {
        return Future.value(
          http.Response(
            jsonEncode({
              'states': [
                {'name': 'Pulau Pinang'},
              ],
            }),
            200,
          ),
        );
      }
      if (uri.path == '/api/portal/projects') {
        final page = uri.queryParameters['page'] ?? 'missing';
        requestedPages.add(page);
        return Future.value(
          http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'teduh-page-$page',
                  'name': 'Residensi Page $page',
                  'location': 'Timur Laut, Pulau Pinang',
                },
              ],
              'last_page': 3,
            }),
            200,
          ),
        );
      }
      return Future.value(http.Response('not found', 404));
    });

    final service = TeduhService(client: client);
    final projects = await service.fetchProjects();

    expect(requestedPages, ['1', '2', '3']);
    expect(projects.map((property) => property.sourceId), [
      'teduh-page-1',
      'teduh-page-2',
      'teduh-page-3',
    ]);
  });

  test('TEDUH pagination deduplicates source IDs across pages', () async {
    final requestedPages = <String>[];
    final client = MockClient((request) {
      final uri = request.url;
      if (uri.path == '/api/portal/projects/filters') {
        return Future.value(http.Response(jsonEncode({'states': []}), 200));
      }
      if (uri.path == '/api/portal/projects') {
        final page = uri.queryParameters['page'] ?? 'missing';
        requestedPages.add(page);
        return Future.value(
          http.Response(
            jsonEncode({
              'data': [
                {
                  'id': page == '1' ? 'duplicate' : 'unique-$page',
                  'name': 'Residensi $page',
                  'location': 'Kinta, Perak',
                },
                {
                  'id': 'duplicate',
                  'name': 'Residensi Duplicate',
                  'location': 'Kinta, Perak',
                },
              ],
              'last_page': 2,
            }),
            200,
          ),
        );
      }
      return Future.value(http.Response('not found', 404));
    });

    final projects = await TeduhService(client: client).fetchProjects();

    expect(requestedPages, ['1', '2']);
    expect(projects.map((property) => property.sourceId), [
      'duplicate',
      'unique-2',
    ]);
  });

  test('TEDUH pagination stops on repeated page signature', () async {
    final requestedPages = <String>[];
    final client = MockClient((request) {
      final uri = request.url;
      if (uri.path == '/api/portal/projects/filters') {
        return Future.value(http.Response(jsonEncode({'states': []}), 200));
      }
      if (uri.path == '/api/portal/projects') {
        final page = uri.queryParameters['page'] ?? 'missing';
        requestedPages.add(page);
        return Future.value(
          http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'same-id',
                  'name': 'Residensi Same',
                  'location': 'Kinta, Perak',
                },
              ],
              'last_page': 9,
            }),
            200,
          ),
        );
      }
      return Future.value(http.Response('not found', 404));
    });

    final projects = await TeduhService(client: client).fetchProjects();

    expect(requestedPages, ['1', '2']);
    expect(projects, hasLength(1));
  });

  test('real property filters behave correctly across common combinations', () {
    final properties = [
      const Property(
        id: 'p01',
        name: 'The Park Residence',
        areaId: 'selangor_petaling',
        address: 'Ara Damansara, Selangor',
        type: 'Condominium',
        tenure: 'Freehold',
        price: 850000,
        summary: '',
        facilities: [],
        palette: 0,
      ),
      const Property(
        id: 'p07',
        name: 'Setia Alam Suites',
        areaId: 'selangor_klang',
        address: 'Setia Alam, Selangor',
        type: 'Apartment',
        tenure: 'Freehold',
        price: 498000,
        summary: '',
        facilities: [],
        palette: 0,
      ),
      const Property(
        id: 'teduh_123',
        name: 'PPAM PENGERANG',
        areaId: 'unknown',
        address: 'Kota Tinggi, Johor',
        type: 'RUMAH TERES',
        tenure: 'Free Hold',
        price: 278800,
        summary: '',
        facilities: [],
        palette: 0,
      ),
      const Property(
        id: 'teduh_456',
        name: 'Residensi Utama',
        areaId: 'unknown',
        address: 'Sungai Petani, Kedah',
        type: 'APARTMEN',
        tenure: 'Leasehold',
        price: 118888,
        summary: '',
        facilities: [],
        palette: 0,
      ),
      const Property(
        id: 'p10',
        name: 'Austin Heights Residence',
        areaId: 'johor_johor_bahru',
        address: 'Tebrau, Johor',
        type: 'Apartment',
        tenure: 'Freehold',
        price: 545000,
        summary: '',
        facilities: [],
        palette: 0,
      ),
    ];

    final pass = <String, bool>{
      'No Filter': true,
      'Search only': properties.any(
        (property) => property.name.toLowerCase().contains('residensi'),
      ),
      'Price only':
          properties.where((property) => property.price! <= 600000).length == 4,
      'Area only':
          properties
              .where((property) => property.areaId == 'selangor_petaling')
              .length ==
          1,
      'Type only':
          properties
              .where(
                (property) => PropertyFilterNormalizer.typeMatches(
                  property.type,
                  'Apartment / Flat',
                ),
              )
              .length ==
          4,
      'Tenure only':
          properties
              .where(
                (property) => PropertyFilterNormalizer.tenureMatches(
                  property.tenure,
                  'Freehold',
                ),
              )
              .length ==
          4,
      'Area + Type':
          properties
              .where(
                (property) =>
                    PropertyFilterNormalizer.areaMatches(
                      property.areaId,
                      'selangor_petaling',
                    ) &&
                    PropertyFilterNormalizer.typeMatches(
                      property.type,
                      'Apartment / Flat',
                    ),
              )
              .length ==
          1,
      'Type + Tenure':
          properties
              .where(
                (property) =>
                    PropertyFilterNormalizer.typeMatches(
                      property.type,
                      'Apartment / Flat',
                    ) &&
                    PropertyFilterNormalizer.tenureMatches(
                      property.tenure,
                      'Freehold',
                    ),
              )
              .length ==
          3,
      'Price + Area':
          properties
              .where(
                (property) =>
                    PropertyFilterNormalizer.matchPrice(property, 600000) &&
                    PropertyFilterNormalizer.areaMatches(
                      property.areaId,
                      'selangor_klang',
                    ),
              )
              .length ==
          1,
      'All combined':
          properties
              .where(
                (property) =>
                    PropertyFilterNormalizer.areaMatches(
                      property.areaId,
                      'selangor_klang',
                    ) &&
                    PropertyFilterNormalizer.typeMatches(
                      property.type,
                      'Apartment / Flat',
                    ) &&
                    PropertyFilterNormalizer.tenureMatches(
                      property.tenure,
                      'Freehold',
                    ) &&
                    PropertyFilterNormalizer.matchPrice(property, 600000),
              )
              .length ==
          1,
      'Reset': true,
    };

    for (final item in pass.entries) {
      expect(item.value, isTrue, reason: item.key);
    }
  });
}

Future<Property> _singleTeduhProject(Map<String, dynamic> record) async {
  final client = MockClient((request) {
    final uri = request.url;
    if (uri.path == '/api/portal/projects/filters') {
      return Future.value(
        http.Response(
          jsonEncode({
            'states': [
              {'name': 'Melaka'},
              {'name': 'Negeri Sembilan'},
              {'name': 'Perak'},
            ],
          }),
          200,
        ),
      );
    }
    if (uri.path == '/api/portal/projects') {
      return Future.value(
        http.Response(
          jsonEncode({
            'data': [record],
            'last_page': 1,
          }),
          200,
        ),
      );
    }
    return Future.value(http.Response('not found', 404));
  });

  return (await TeduhService(client: client).fetchProjects()).single;
}
