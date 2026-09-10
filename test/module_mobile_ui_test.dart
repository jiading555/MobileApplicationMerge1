import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/features/analysis/analysis_screen.dart';
import 'package:smart_property_advisor/features/map/property_map_screen.dart';
import 'package:smart_property_advisor/features/search/property_detail_screen.dart';
import 'package:smart_property_advisor/features/search/property_search_screen.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final entry in _moduleScreens().entries) {
      testWidgets('${entry.key} fits phone viewport $size', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(size: size),
              child: child!,
            ),
            home: AppScope(notifier: _moduleState(), child: entry.value),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  }
}

Map<String, Widget> _moduleScreens() {
  return const {
    'Property Search': PropertySearchScreen(),
    'Property Details': PropertyDetailScreen(propertyId: 'teduh_1'),
    'Area Analytics': AnalysisScreen(),
    'Map': PropertyMapScreen(),
  };
}

AppState _moduleState() {
  final state = AppState();
  state.isLoading = false;
  state.isUsingCloudAreaProfiles = true;
  state.isUsingCloudProperties = true;
  state.areas = const [
    AreaData(
      id: 'selangor_klang',
      name: 'Klang',
      state: 'Selangor',
      population: 1088000,
      medianIncome: 9120,
      safetyScore: 84,
      transportScore: 72,
      schools: 112,
      snapshotDate: '2025',
      source: 'OpenDOSM; data.gov.my',
      isGovernmentProfile: true,
    ),
  ];
  state.properties = [
    Property(
      id: 'teduh_1',
      name: 'Residensi Demo Klang',
      areaId: 'selangor_klang',
      address: 'Klang, Selangor',
      type: '',
      tenure: '',
      state: 'Selangor',
      district: 'Klang',
      price: 300000,
      priceMin: 280000,
      priceMax: 350000,
      latitude: 3.03,
      longitude: 101.44,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['PR1MA Homes', 'Klang'],
      palette: 1,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'TEDUH_1',
      scheme: 'PR1MA Homes',
      developerName: 'Demo Developer Sdn Bhd',
      totalUnits: 100,
      availableUnits: 12,
      unitTypes: const ['APARTMEN'],
      sourceUrl: 'https://teduh.kpkt.gov.my/api/portal/projects',
      retrievedAt: DateTime.utc(2026, 9, 9),
    ),
  ];
  return state;
}
