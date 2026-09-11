import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/features/search/property_detail_screen.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/models/user_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  test('TEDUH model mapping does not fabricate nearby facilities', () {
    final property = Property.fromTeduhJson(
      {
        'source_id': 'SPNB_9',
        'project_name': 'Taman Nusa Idaman, Kuala Ping',
        'state': 'Terengganu',
        'district': null,
        'scheme': 'Syarikat Perumahan Negara Berhad (SPNB)',
        'developer_name': 'Syarikat Perumahan Negara Berhad (SPNB)',
      },
      areaId: 'unknown',
      palette: 0,
    );

    expect(property.facilities, isEmpty);
    expect(property.scheme, 'Syarikat Perumahan Negara Berhad (SPNB)');
    expect(property.developerName, 'Syarikat Perumahan Negara Berhad (SPNB)');
    expect(property.state, 'Terengganu');
    expect(property.type, isEmpty);
    expect(property.tenure, isEmpty);
    expect(
      property.summary,
      'Official housing project information sourced from TEDUH.',
    );
  });

  testWidgets('Taman Nusa Idaman detail hides unavailable optional values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = AppState();
    state.isLoading = false;
    state.isUsingCloudProperties = true;
    state.areas = const [];
    state.properties = [
      Property.fromTeduhJson(
        {
          'source_id': 'SPNB_9',
          'project_name': 'Taman Nusa Idaman, Kuala Ping',
          'state': 'Terengganu',
          'district': null,
          'scheme': 'Syarikat Perumahan Negara Berhad (SPNB)',
          'price_min': 68000,
          'price_max': 292000,
          'total_units': 32,
          'available_units': null,
          'property_type': null,
          'developer_name': 'Syarikat Perumahan Negara Berhad (SPNB)',
          'unit_types': [
            'RUMAH TERES 1 TINGKAT (EGENIA)',
            'RUMAH TERES 1 TINGKAT (DEHASIA)',
            'RUMAH TERES 1 TINGKAT (MADHUCA)',
            'RUMAH BERKEMBAR 1 TINGKAT (MILLETIA)',
          ],
          'unit_options': [
            {
              'source_unit_id': 'SPNB_901',
              'unit_type': 'RUMAH TERES 1 TINGKAT (EGENIA)',
              'price_start': 68000,
              'price_from_text': 'RM 68,000.00',
              'size_sqft': 800,
              'size_text': '800 kps',
              'image_url': 'https://teduh.kpkt.gov.my/images/egenia.jpg',
            },
            {
              'source_unit_id': 'SPNB_902',
              'unit_type': 'RUMAH BERKEMBAR 1 TINGKAT (MILLETIA)',
              'price_start': 292000,
              'size_sqft': 1200,
            },
          ],
          'source_url': 'https://teduh.kpkt.gov.my/api/portal/projects',
          'external_project_url': 'https://teduh.kpkt.gov.my/projek/spnb-9',
        },
        areaId: 'unknown',
        palette: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          notifier: state,
          child: const PropertyDetailScreen(propertyId: 'teduh_SPNB_9'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('Project Price Range'), findsOneWidget);
    expect(find.text('RM 68,000 - RM 292,000'), findsOneWidget);
    expect(find.text('Tenure not available'), findsNothing);
    expect(find.text('Public housing'), findsNothing);
    expect(find.text('Nearby facilities'), findsNothing);
    expect(find.text('Area signals'), findsNothing);
    expect(find.text('Current area profile'), findsNothing);
    expect(find.textContaining('Unknown'), findsNothing);
    expect(
      find.text('Area data is unavailable for this property.'),
      findsWidgets,
    );
    expect(find.text('Available units'), findsOneWidget);
    expect(find.text('Unit types'), findsNothing);
    expect(find.text('RUMAH TERES 1 TINGKAT (EGENIA)'), findsOneWidget);
    expect(find.text('RUMAH BERKEMBAR 1 TINGKAT (MILLETIA)'), findsOneWidget);
    expect(find.text('800 kps'), findsOneWidget);
    expect(find.text('From RM 68,000'), findsOneWidget);
    expect(
      find.text('Official housing project information sourced from TEDUH.'),
      findsOneWidget,
    );
    expect(
      find.text('Scheme: Syarikat Perumahan Negara Berhad (SPNB).'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TEDUH detail shows single project price without fake range', (
    tester,
  ) async {
    final state = AppState();
    state.isLoading = false;
    state.properties = [
      Property.fromTeduhJson(
        {
          'source_id': 'PR1MA_1',
          'project_name': 'Residensi Single',
          'price_min': 266000,
          'price_max': 266000,
          'source_url': 'https://teduh.kpkt.gov.my/api/portal/projects',
        },
        areaId: 'unknown',
        palette: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          notifier: state,
          child: const PropertyDetailScreen(propertyId: 'teduh_PR1MA_1'),
        ),
      ),
    );

    expect(find.text('Project Price'), findsOneWidget);
    expect(find.text('RM 266,000'), findsOneWidget);
    expect(find.text('Project Price Range'), findsNothing);
    expect(find.text('RM 266,000 - RM 266,000'), findsNothing);
  });

  testWidgets('TEDUH detail falls back to unit_types without unit_options', (
    tester,
  ) async {
    final state = AppState();
    state.isLoading = false;
    state.properties = [
      Property.fromTeduhJson(
        {
          'source_id': 'SPNB_10',
          'project_name': 'Residensi Unit Type Fallback',
          'unit_types': ['Rumah Bandar', 'Rumah Teres 2 Tingkat'],
        },
        areaId: 'unknown',
        palette: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          notifier: state,
          child: const PropertyDetailScreen(propertyId: 'teduh_SPNB_10'),
        ),
      ),
    );

    expect(find.text('Unit types'), findsOneWidget);
    expect(find.text('Rumah Bandar'), findsOneWidget);
    expect(find.text('Rumah Teres 2 Tingkat'), findsOneWidget);
  });

  testWidgets(
    'verified property_type is visible but Public fallback is hidden',
    (tester) async {
      final state = AppState();
      state.isLoading = false;
      state.properties = [
        Property.fromTeduhJson(
          {
            'source_id': 'VERIFIED_1',
            'project_name': 'Verified Type Project',
            'property_type': 'Apartment',
          },
          areaId: 'unknown',
          palette: 0,
        ),
        const Property(
          id: 'teduh_legacy_public',
          name: 'Legacy Public Project',
          areaId: 'unknown',
          address: 'Malaysia',
          type: 'Public',
          tenure: '',
          summary: 'Official housing project information sourced from TEDUH.',
          facilities: [],
          palette: 0,
          source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            notifier: state,
            child: const PropertyDetailScreen(propertyId: 'teduh_VERIFIED_1'),
          ),
        ),
      );

      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Apartment'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            notifier: state,
            child: const PropertyDetailScreen(
              propertyId: 'teduh_legacy_public',
            ),
          ),
        ),
      );

      expect(find.text('Type'), findsNothing);
      expect(find.text('Public'), findsNothing);
    },
  );

  testWidgets('valid source URL opens through external launcher', (
    tester,
  ) async {
    final launcher = _FakeUrlLauncher();
    final originalLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

    final state = AppState();
    state.isLoading = false;
    state.properties = [
      Property.fromTeduhJson(
        {
          'source_id': 'LINK_1',
          'project_name': 'Linked Project',
          'source_url': 'https://teduh.kpkt.gov.my/api/portal/projects',
        },
        areaId: 'unknown',
        palette: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          notifier: state,
          child: const PropertyDetailScreen(propertyId: 'teduh_LINK_1'),
        ),
      ),
    );

    expect(
      find.text('https://teduh.kpkt.gov.my/api/portal/projects'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Open link'));
    await tester.pump();

    expect(launcher.launchedUrls, [
      'https://teduh.kpkt.gov.my/api/portal/projects',
    ]);
  });

  testWidgets(
    'scoreable property with matched area signals shows numeric suitability',
    (tester) async {
      final property = _huluProperty(
        id: 'SCORE_1',
        state: 'terengganu',
        district: 'Hulu-Terengganu',
        areaId: 'TERENGGANU_HULU-TERENGGANU',
      );
      final state = _detailState(
        property: property,
        areas: const [_huluTerengganuArea],
      );

      await _pumpDetail(tester, state, property.id);

      expect(find.text('Area signals'), findsOneWidget);
      expect(find.text('94/100'), findsOneWidget);
      expect(find.text('Current area profile'), findsOneWidget);
      expect(find.text('Hulu Terengganu, Terengganu'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('-'), findsNothing);
      expect(
        find.text('Change advisor filters to include this property.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'filtered-out property still shows calculated suitability when scoreable',
    (tester) async {
      final property = _huluProperty(id: 'FILTERED_1');
      final state = _detailState(
        property: property,
        areas: const [_huluTerengganuArea],
        preferences: const UserPreferences(propertyType: 'Apartment / Flat'),
      );

      expect(state.recommendations, isEmpty);

      await _pumpDetail(tester, state, property.id);

      expect(find.text('78'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('-'), findsNothing);
      expect(
        find.text(
          'This property can be scored, but it does not currently match all advisor preferences.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Change advisor filters to include this property.'),
        findsNothing,
      );
    },
  );

  testWidgets('property without matching area data keeps neutral dash state', (
    tester,
  ) async {
    final property = _huluProperty(id: 'NO_AREA_1');
    final state = _detailState(property: property, areas: const []);

    await _pumpDetail(tester, state, property.id);

    expect(find.text('-'), findsOneWidget);
    expect(find.text('/100'), findsNothing);
    expect(
      find.text('Area data is unavailable for this property.'),
      findsWidgets,
    );
    expect(find.text('78'), findsNothing);
  });

  testWidgets(
    'matched area with missing optional safety signal still calculates score',
    (tester) async {
      final property = _huluProperty(id: 'OPTIONAL_NULL_1');
      final state = _detailState(
        property: property,
        areas: const [_huluTerengganuAreaWithoutSafety],
      );

      await _pumpDetail(tester, state, property.id);

      expect(find.text('70'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('-'), findsNothing);
      expect(
        find.text(
          'Insufficient property or area data to calculate suitability.',
        ),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  AppState state,
  String propertyId,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: AppScope(
        notifier: state,
        child: PropertyDetailScreen(propertyId: propertyId),
      ),
    ),
  );
}

AppState _detailState({
  required Property property,
  required List<AreaData> areas,
  UserPreferences preferences = const UserPreferences(),
}) {
  final state = AppState();
  state.isLoading = false;
  state.properties = [property];
  state.areas = areas;
  state.preferences = preferences;
  return state;
}

Property _huluProperty({
  required String id,
  String state = 'Terengganu',
  String district = 'Hulu Terengganu',
  String areaId = 'terengganu_hulu_terengganu',
}) {
  return Property.fromTeduhJson(
    {
      'source_id': id,
      'project_name': 'Hulu Terengganu Residence',
      'state': state,
      'district': district,
      'property_type': 'Rumah Teres 1 Tingkat',
      'price_min': 300000,
    },
    areaId: areaId,
    palette: 0,
  );
}

const _huluTerengganuArea = AreaData(
  id: 'terengganu_hulu_terengganu',
  name: 'Hulu Terengganu',
  state: 'Terengganu',
  population: 75000,
  medianIncome: 5090,
  safetyScore: 94,
  transportScore: 80,
  schools: 10,
  priceGrowth: 28.1,
  snapshotDate: '2025',
  source: 'OpenDOSM; data.gov.my',
  isGovernmentProfile: true,
);

const _huluTerengganuAreaWithoutSafety = AreaData(
  id: 'terengganu_hulu_terengganu',
  name: 'Hulu Terengganu',
  state: 'Terengganu',
  population: 75000,
  medianIncome: 5090,
  safetyScore: null,
  transportScore: 80,
  schools: 10,
  priceGrowth: 28.1,
  snapshotDate: '2025',
  source: 'OpenDOSM; data.gov.my',
  isGovernmentProfile: true,
);

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    expect(options.mode, PreferredLaunchMode.externalApplication);
    return true;
  }
}
