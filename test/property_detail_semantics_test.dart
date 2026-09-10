import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/features/search/property_detail_screen.dart';
import 'package:smart_property_advisor/models/property.dart';
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
      find.text(
        'No matched district area profile is available for this property.',
      ),
      findsOneWidget,
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
}

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
