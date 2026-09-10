import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/features/search/property_search_screen.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/models/area_data.dart';

void main() {
  testWidgets('PropertySearchScreen shows filter labels and opens menus', (
    tester,
  ) async {
    final state = AppState();
    state.properties = [
      Property(
        id: 'p1',
        name: 'Condo A',
        areaId: 'kuala_lumpur_kuala_lumpur_city',
        address: 'KL',
        type: 'Condominium',
        tenure: 'Freehold',
        state: 'Kuala Lumpur',
        price: 500000,
        summary: 'sum',
        facilities: [],
        palette: 0,
        scheme: 'Perumahan Penjawat Awam Malaysia (PPAM)',
      ),
    ];
    state.areas = [
      AreaData(
        id: 'kuala_lumpur_kuala_lumpur_city',
        name: 'Kuala Lumpur City',
        state: 'Kuala Lumpur',
        population: 0,
        populationGrowth: 0,
        medianIncome: 0,
        safetyScore: 0,
        connectivityScore: 0,
        transportScore: 0,
        schools: 0,
        hospitals: 0,
        averagePricePsf: 0,
        rentalYield: 0,
        priceGrowth: 0,
        priceHistory: [],
        snapshotDate: '2024',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(notifier: state, child: const PropertySearchScreen()),
      ),
    );

    expect(find.text('Any State'), findsOneWidget);
    expect(find.text('Any Area'), findsOneWidget);
    expect(find.text('Any Type'), findsOneWidget);
    expect(find.text('Any Programme'), findsOneWidget);
    expect(find.text('Any Budget'), findsOneWidget);
    expect(find.text('Reload Latest Data'), findsNothing);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);

    expect(find.text('1 properties found'), findsOneWidget);

    await tester.tap(find.text('Any State'));
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur'), findsWidgets);

    await tester.tap(find.text('Kuala Lumpur').last);
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur'), findsWidgets);

    await tester.tap(find.text('Any Type'));
    await tester.pumpAndSettle();
    expect(find.text('Apartment / Flat'), findsWidgets);
    expect(find.text('Condominium'), findsNothing);
    await tester.tap(find.text('Apartment / Flat').last);
    await tester.pumpAndSettle();
    expect(find.text('1 properties found'), findsOneWidget);

    await tester.tap(find.text('Any Programme'));
    await tester.pumpAndSettle();
    expect(find.text('PPAM'), findsWidgets);
    await tester.tap(find.text('PPAM').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.restart_alt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Any State'), findsOneWidget);
    expect(find.text('Any Budget'), findsOneWidget);
  });

  testWidgets(
    'PropertySearchScreen filters null property_type records by unit_types',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      state.properties = [
        _teduhProperty(
          id: 'p1',
          name: 'Residensi Kinta Apartment',
          state: 'Perak',
          district: 'Kinta',
          scheme: 'PR1MA Homes',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
        _teduhProperty(
          id: 'p2',
          name: 'Residensi Kinta Terrace',
          state: 'Perak',
          district: 'Kinta',
          scheme: 'PPAM',
          price: 700000,
          unitTypes: const ['RUMAH TERES'],
        ),
        _teduhProperty(
          id: 'p3',
          name: 'Residensi Klang Semi D',
          state: 'Selangor',
          district: 'Klang',
          scheme: 'PR1MA Homes',
          price: 400000,
          unitTypes: const ['RUMAH BERKEMBAR'],
        ),
      ];
      state.areas = const [];

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(notifier: state, child: const PropertySearchScreen()),
        ),
      );

      expect(find.text('3 properties found'), findsOneWidget);

      await tester.tap(find.text('Any Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apartment / Flat').last);
      await tester.pumpAndSettle();
      expect(find.text('1 properties found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();
      expect(find.text('3 properties found'), findsOneWidget);

      await tester.tap(find.text('Any Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terrace House').last);
      await tester.pumpAndSettle();
      expect(find.text('1 properties found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Any Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semi-Detached').last);
      await tester.pumpAndSettle();
      expect(find.text('1 properties found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Any State'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perak').last);
      await tester.pumpAndSettle();
      expect(find.text('2 properties found'), findsOneWidget);

      await tester.tap(find.text('Any Area'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kinta, Perak').last);
      await tester.pumpAndSettle();
      expect(find.text('2 properties found'), findsOneWidget);

      await tester.tap(find.text('Any Programme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PR1MA Homes').last);
      await tester.pumpAndSettle();
      expect(find.text('1 properties found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Any Budget'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(-1000, 0));
      await tester.pump();
      await tester.tap(find.text('Apply price'));
      await tester.pumpAndSettle();
      expect(find.text('1 properties found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();
      expect(find.text('3 properties found'), findsOneWidget);
    },
  );

  testWidgets('PropertySearchScreen builds area options dynamically', (
    tester,
  ) async {
    final state = AppState();
    state.properties = const [
      Property(
        id: 'p1',
        name: 'Residensi Kinta',
        areaId: 'perak_kinta',
        address: 'Kinta, Perak',
        type: 'APARTMEN',
        tenure: 'Tenure not available',
        state: 'Perak',
        district: 'Kinta',
        price: 300000,
        summary: 'sum',
        facilities: [],
        palette: 0,
        scheme: 'PR1MA Homes',
      ),
    ];
    state.areas = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(notifier: state, child: const PropertySearchScreen()),
      ),
    );

    await tester.tap(find.text('Any Area'));
    await tester.pumpAndSettle();

    expect(find.text('Kinta, Perak'), findsWidgets);
  });

  testWidgets(
    'PropertySearchScreen keyword search includes district and state',
    (tester) async {
      final state = AppState();
      state.properties = const [
        Property(
          id: 'p1',
          name: 'Residensi Harmoni',
          areaId: 'perak_kinta',
          address: 'Official TEDUH listing',
          type: 'Public housing',
          tenure: 'Tenure not available',
          state: 'Perak',
          district: 'Kinta',
          summary: 'sum',
          facilities: [],
          palette: 0,
        ),
      ];
      state.areas = const [];

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(notifier: state, child: const PropertySearchScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'kinta');
      await tester.pump();

      expect(find.text('1 properties found'), findsOneWidget);
    },
  );

  testWidgets('PropertySearchScreen resets stale filters after data reload', (
    tester,
  ) async {
    final state = AppState();
    state.properties = const [
      Property(
        id: 'p1',
        name: 'Residensi Kinta',
        areaId: 'perak_kinta',
        address: 'Kinta, Perak',
        type: 'APARTMEN',
        tenure: 'Tenure not available',
        state: 'Perak',
        district: 'Kinta',
        summary: 'sum',
        facilities: [],
        palette: 0,
      ),
    ];
    state.areas = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(notifier: state, child: const PropertySearchScreen()),
      ),
    );

    await tester.tap(find.text('Any State'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perak').last);
    await tester.pumpAndSettle();
    expect(find.text('1 properties found'), findsOneWidget);

    state.properties = const [
      Property(
        id: 'p2',
        name: 'Residensi Klang',
        areaId: 'selangor_klang',
        address: 'Klang, Selangor',
        type: 'APARTMEN',
        tenure: 'Tenure not available',
        state: 'Selangor',
        district: 'Klang',
        summary: 'sum',
        facilities: [],
        palette: 0,
      ),
    ];
    state.notifyListeners();
    await tester.pump();

    expect(find.text('Any State'), findsOneWidget);
    expect(find.text('1 properties found'), findsOneWidget);
  });
}

Property _teduhProperty({
  required String id,
  required String name,
  required String state,
  required String district,
  required String scheme,
  required int price,
  required List<String> unitTypes,
}) {
  return Property.fromTeduhJson(
    {
      'source_id': id,
      'project_name': name,
      'state': state,
      'district': district,
      'scheme': scheme,
      'price_min': price,
      'property_type': null,
      'unit_types': unitTypes,
    },
    areaId: '${state.toLowerCase()}_${district.toLowerCase()}',
    palette: 0,
  );
}
