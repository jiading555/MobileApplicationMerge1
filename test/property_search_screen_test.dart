import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/core/utils/location_normalizer.dart';
import 'package:smart_property_advisor/features/search/property_search_screen.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/models/area_data.dart';

void main() {
  testWidgets('PropertySearchScreen shows final filters and opens menus', (
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
        district: 'Kuala Lumpur City',
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
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: AppScope(notifier: state, child: const PropertySearchScreen()),
      ),
    );

    expect(find.text('Any State'), findsOneWidget);
    expect(find.text('Any Area'), findsOneWidget);
    expect(find.text('Any Type'), findsOneWidget);
    expect(find.text('Any Programme'), findsOneWidget);
    expect(find.text('Any Budget'), findsNothing);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Reload Latest Data'), findsNothing);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsNothing);

    expect(find.text('1 properties found'), findsOneWidget);

    await tester.tap(find.text('Any State'));
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur'), findsWidgets);

    await tester.tap(find.text('Kuala Lumpur').last);
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur'), findsWidgets);

    await tester.tap(find.text('Any Area'));
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur City'), findsWidgets);
    await tester.tap(find.text('Kuala Lumpur City').last);
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur City'), findsOneWidget);

    await tester.tap(find.text('Any Type'));
    await tester.pumpAndSettle();
    expect(find.text('Apartment / Flat'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Condominium'),
      ),
      findsNothing,
    );
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
    expect(find.text('Any Area'), findsOneWidget);
    expect(find.text('Any Budget'), findsNothing);
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
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
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
      await tester.tap(find.text('Kinta').last);
      await tester.pumpAndSettle();
      expect(find.text('2 properties found'), findsOneWidget);

      await tester.tap(find.text('Any Programme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PR1MA Homes').last);
      await tester.pumpAndSettle();
      expect(find.text('1 properties found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pumpAndSettle();
      expect(find.text('3 properties found'), findsOneWidget);
    },
  );

  testWidgets('Area is not populated nationwide when State is Any State', (
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
      Property(
        id: 'p2',
        name: 'Residensi Kemaman',
        areaId: 'terengganu_kemaman',
        address: 'Kemaman, Terengganu',
        type: 'APARTMEN',
        tenure: 'Tenure not available',
        state: 'Terengganu',
        district: 'Kemaman',
        summary: 'sum',
        facilities: [],
        palette: 0,
        scheme: 'PPAM',
      ),
    ];
    state.areas = const [];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: AppScope(notifier: state, child: const PropertySearchScreen()),
      ),
    );

    await tester.tap(find.text('Any Area'));
    await tester.pumpAndSettle();

    expect(find.text('Kinta'), findsNothing);
    expect(find.text('Kemaman'), findsNothing);
    expect(find.text('Any Area'), findsOneWidget);
  });

  testWidgets('Selecting Terengganu only exposes Terengganu areas', (
    tester,
  ) async {
    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'besut',
        name: 'Residensi Besut',
        state: 'Terengganu',
        district: 'Besut',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'dungun',
        name: 'Residensi Dungun',
        state: 'Terengganu',
        district: 'Dungun',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'hulu_terengganu',
        name: 'Residensi Hulu Terengganu',
        state: 'Terengganu',
        district: 'Hulu Terengganu',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'kemaman',
        name: 'Residensi Kemaman',
        state: 'Terengganu',
        district: 'Kemaman',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'kuala_nerus',
        name: 'Residensi Kuala Nerus',
        state: 'Terengganu',
        district: 'Kuala Nerus',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'kuala_terengganu',
        name: 'Residensi Kuala Terengganu',
        state: 'Terengganu',
        district: 'Kuala Terengganu',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'marang',
        name: 'Residensi Marang',
        state: 'Terengganu',
        district: 'Marang',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'setiu',
        name: 'Residensi Setiu',
        state: 'Terengganu',
        district: 'Setiu',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'kinta',
        name: 'Residensi Kinta',
        state: 'Perak',
        district: 'Kinta',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    await tester.tap(find.text('Any State'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terengganu').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Any Area'));
    await tester.pumpAndSettle();

    for (final area in const [
      'Besut',
      'Dungun',
      'Hulu Terengganu',
      'Kemaman',
      'Kuala Nerus',
      'Kuala Terengganu',
      'Marang',
      'Setiu',
    ]) {
      expect(find.text(area), findsWidgets);
    }
    expect(find.text('Kinta'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('Kemaman, Terengganu'),
      ),
      findsNothing,
    );
  });

  testWidgets('Kuala Lumpur area dropdown uses property localities only', (
    tester,
  ) async {
    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'setiawangsa',
        name: 'Residensi Setiawangsa',
        state: 'Kuala Lumpur',
        district: 'Setiawangsa',
        scheme: 'Residensi Wilayah',
        price: 300000,
        unitTypes: const ['APARTMEN'],
        areaId: 'kuala_lumpur_w_p_kuala_lumpur',
      ),
      _teduhProperty(
        id: 'cheras',
        name: 'Residensi Cheras',
        state: 'Kuala Lumpur',
        district: 'Cheras',
        scheme: 'Residensi Wilayah',
        price: 320000,
        unitTypes: const ['APARTMEN'],
        areaId: 'kuala_lumpur_w_p_kuala_lumpur',
      ),
    ];
    state.areas = const [
      AreaData(
        id: 'kuala_lumpur_w_p_kuala_lumpur',
        name: 'W P Kuala Lumpur',
        state: 'Kuala Lumpur',
        isGovernmentProfile: true,
      ),
    ];

    await _pumpSearch(tester, state);

    await tester.tap(find.text('Any State'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuala Lumpur').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Any Area'));
    await tester.pumpAndSettle();

    expect(find.text('Setiawangsa'), findsWidgets);
    expect(find.text('Cheras'), findsWidgets);
    expect(find.text('W P Kuala Lumpur'), findsNothing);

    await tester.tap(find.text('Setiawangsa').last);
    await tester.pumpAndSettle();

    expect(find.text('1 properties found'), findsOneWidget);
    expect(find.text('Residensi Setiawangsa'), findsOneWidget);
    expect(find.text('Residensi Cheras'), findsNothing);

    await tester.enterText(find.byType(TextField), 'cheras');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('0 properties found'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restart_alt_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cheras');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1 properties found'), findsOneWidget);
    expect(find.text('Residensi Cheras'), findsOneWidget);
  });

  testWidgets('Changing State resets selected Area', (tester) async {
    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'kemaman',
        name: 'Residensi Kemaman',
        state: 'Terengganu',
        district: 'Kemaman',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'kinta',
        name: 'Residensi Kinta',
        state: 'Perak',
        district: 'Kinta',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    await tester.tap(find.text('Any State'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terengganu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any Area'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kemaman').last);
    await tester.pumpAndSettle();

    expect(find.text('Kemaman'), findsOneWidget);
    expect(find.text('1 properties found'), findsOneWidget);

    await tester.tap(find.text('Terengganu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perak').last);
    await tester.pumpAndSettle();

    expect(find.text('Any Area'), findsOneWidget);
    expect(find.text('Kemaman'), findsNothing);
    expect(find.text('1 properties found'), findsOneWidget);
  });

  testWidgets(
    'State Area Property Type and Housing Programme filtering works together',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      state.properties = [
        _teduhProperty(
          id: 'target',
          name: 'Residensi Kemaman Apartment PPAM',
          state: 'Terengganu',
          district: 'Kemaman',
          scheme: 'PPAM',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
        _teduhProperty(
          id: 'wrong_type',
          name: 'Residensi Kemaman Terrace PPAM',
          state: 'Terengganu',
          district: 'Kemaman',
          scheme: 'PPAM',
          price: 300000,
          unitTypes: const ['RUMAH TERES'],
        ),
        _teduhProperty(
          id: 'wrong_scheme',
          name: 'Residensi Kemaman Apartment PR1MA',
          state: 'Terengganu',
          district: 'Kemaman',
          scheme: 'PR1MA Homes',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
        _teduhProperty(
          id: 'wrong_area',
          name: 'Residensi Besut Apartment PPAM',
          state: 'Terengganu',
          district: 'Besut',
          scheme: 'PPAM',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
        _teduhProperty(
          id: 'wrong_state',
          name: 'Residensi Kinta Apartment PPAM',
          state: 'Perak',
          district: 'Kinta',
          scheme: 'PPAM',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
      ];
      state.areas = const [];

      await _pumpSearch(tester, state);
      expect(find.text('5 properties found'), findsOneWidget);

      await tester.tap(find.text('Any State'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terengganu').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Any Area'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kemaman').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Any Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apartment / Flat').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Any Programme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PPAM').last);
      await tester.pumpAndSettle();

      expect(find.text('1 properties found'), findsOneWidget);
      expect(find.text('Residensi Kemaman Apartment PPAM'), findsOneWidget);
    },
  );

  testWidgets('PropertySearchScreen has no phone-size overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'target',
        name: 'Residensi Kuala Terengganu Apartment PPAM',
        state: 'Terengganu',
        district: 'Kuala Terengganu',
        scheme: 'Perumahan Penjawat Awam Malaysia (PPAM)',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.text('Any State'), findsOneWidget);
    expect(find.text('Any Area'), findsOneWidget);
    expect(find.text('Any Type'), findsOneWidget);
    expect(find.text('Any Programme'), findsOneWidget);
  });

  testWidgets('portrait search filters stay in one horizontal scroll row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'scroll_filters',
        name: 'Residensi Scroll Filters',
        state: 'Terengganu',
        district: 'Kuala Terengganu',
        scheme: 'Perumahan Penjawat Awam Malaysia (PPAM)',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    final filterRow = find.byKey(const ValueKey('property-filter-scroll-row'));
    final scrollWidget = tester.widget<SingleChildScrollView>(filterRow);

    expect(scrollWidget.scrollDirection, Axis.horizontal);
    expect(
      find.descendant(of: filterRow, matching: find.byType(Wrap)),
      findsNothing,
    );

    final stateButton = find.byKey(
      const ValueKey('property-filter-state-button'),
    );
    final areaButton = find.byKey(
      const ValueKey('property-filter-area-button'),
    );
    final typeButton = find.byKey(
      const ValueKey('property-filter-type-button'),
    );
    final programmeButton = find.byKey(
      const ValueKey('property-filter-programme-button'),
    );
    final rowTop = tester.getTopLeft(stateButton).dy;

    expect(tester.getTopLeft(areaButton).dy, rowTop);
    expect(tester.getTopLeft(typeButton).dy, rowTop);
    expect(tester.getTopLeft(programmeButton).dy, rowTop);
    expect(
      tester.getTopRight(programmeButton).dx,
      greaterThan(tester.getTopRight(filterRow).dx),
    );
  });

  testWidgets('landscape search keeps property results visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      for (var index = 0; index < 6; index += 1)
        _teduhProperty(
          id: 'landscape_$index',
          name: 'Residensi Landscape $index',
          state: 'Selangor',
          district: 'Petaling',
          scheme: 'Rumah Selangorku',
          price: 300000 + index,
          unitTypes: const ['APARTMEN'],
        ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('6 properties found'), findsOneWidget);
    expect(find.text('Residensi Landscape 0'), findsOneWidget);
  });

  testWidgets('tablet search summary keeps source label trailing aligned', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.isUsingCloudProperties = true;
    state.properties = [
      for (var index = 0; index < 206; index += 1)
        _teduhProperty(
          id: 'summary_$index',
          name: 'Residensi Summary $index',
          state: 'Selangor',
          district: 'Petaling',
          scheme: 'Rumah Selangorku',
          price: 300000 + index,
          unitTypes: const ['APARTMEN'],
        ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    final resultCount = find.text('206 properties found');
    final source = find.text('Source: Supabase / TEDUH');

    expect(tester.takeException(), isNull);
    expect(resultCount, findsOneWidget);
    expect(source, findsOneWidget);

    final resultRect = tester.getRect(resultCount);
    final sourceRect = tester.getRect(source);
    final sourceGroupRect = tester.getRect(
      find.byKey(const ValueKey('property-search-source-summary')),
    );

    expect(resultRect.left, lessThanOrEqualTo(24));
    expect(sourceRect.left, greaterThan(resultRect.right));
    expect(sourceGroupRect.right, greaterThanOrEqualTo(876));
  });

  testWidgets('Property search cards do not use excessive tablet grid height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'height',
        name: 'Residensi Natural Height',
        state: 'Perak',
        district: 'Kinta',
        scheme: 'SPNB',
        price: 300000,
        unitTypes: const ['RUMAH TERES'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    expect(find.byType(GridView), findsNothing);
    final cardFinder = find.ancestor(
      of: find.text('Residensi Natural Height'),
      matching: find.byType(Card),
    );
    expect(cardFinder, findsOneWidget);
    final cardHeight = tester.getSize(cardFinder).height;
    expect(cardHeight, greaterThan(300));
    expect(cardHeight, lessThan(420));
  });

  testWidgets('Property card shows type and housing programme when available', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'metadata',
        name: 'Residensi Metadata',
        state: 'Perak',
        district: 'Kinta',
        scheme: 'Perumahan Penjawat Awam Malaysia (PPAM)',
        price: 300000,
        unitTypes: const ['RUMAH TERES'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    expect(find.text('Rumah Teres'), findsOneWidget);
    expect(find.text('Programme: PPAM'), findsOneWidget);
    expect(find.text('TEDUH / KPKT'), findsOneWidget);
  });

  testWidgets('Missing optional card metadata does not show placeholder rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'missing_metadata',
        name: 'Residensi Sparse',
        state: 'Perak',
        district: 'Kinta',
        scheme: '',
        price: 300000,
        unitTypes: const [],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    expect(find.textContaining('Programme:'), findsNothing);
    expect(find.text('N/A'), findsNothing);
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('Not Available'), findsNothing);
  });

  testWidgets(
    'View Details action opens the existing property details screen',
    (tester) async {
      final state = AppState();
      state.properties = [
        _teduhProperty(
          id: 'details',
          name: 'Residensi Details',
          state: 'Perak',
          district: 'Kinta',
          scheme: 'SPNB',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
      ];
      state.areas = const [];

      await _pumpSearch(tester, state);
      await tester.ensureVisible(find.text('View Details'));
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      expect(find.text('Property details'), findsOneWidget);
      expect(find.text('Residensi Details'), findsOneWidget);
    },
  );

  testWidgets('Favourite action still toggles from property search card', (
    tester,
  ) async {
    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'favourite',
        name: 'Residensi Favourite',
        state: 'Perak',
        district: 'Kinta',
        scheme: 'SPNB',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pump();

    expect(state.isFavourite('teduh_favourite'), isTrue);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('PropertySearchScreen has no desktop grid overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'desktop_1',
        name: 'Residensi Kuala Terengganu Apartment PPAM With Longer Name',
        state: 'Terengganu',
        district: 'Kuala Terengganu',
        scheme: 'Perumahan Penjawat Awam Malaysia (PPAM)',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'desktop_2',
        name: 'Residensi Kemaman Terrace SPNB With Longer Name',
        state: 'Terengganu',
        district: 'Kemaman',
        scheme: 'SPNB',
        price: 350000,
        unitTypes: const ['RUMAH TERES'],
      ),
      _teduhProperty(
        id: 'desktop_3',
        name: 'Residensi Besut Semi Detached PR1MA With Longer Name',
        state: 'Terengganu',
        district: 'Besut',
        scheme: 'PR1MA Homes',
        price: 400000,
        unitTypes: const ['RUMAH BERKEMBAR'],
      ),
    ];
    state.areas = const [];

    await _pumpSearch(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.text('3 properties found'), findsOneWidget);
    expect(find.text('View Details'), findsNWidgets(3));
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
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: AppScope(notifier: state, child: const PropertySearchScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'kinta');
      await tester.pump(const Duration(milliseconds: 250));

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
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
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

Future<void> _pumpSearch(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const PropertySearchScreen(),
      ),
    ),
  );
}

Property _teduhProperty({
  required String id,
  required String name,
  required String state,
  required String district,
  required String scheme,
  required int price,
  required List<String> unitTypes,
  String? propertyType,
  String? areaId,
}) {
  return Property.fromTeduhJson(
    {
      'source_id': id,
      'project_name': name,
      'state': state,
      'district': district,
      'scheme': scheme,
      'price_min': price,
      'property_type': propertyType,
      'unit_types': unitTypes,
    },
    areaId: areaId ?? LocationNormalizer.canonicalAreaId(state, district),
    palette: 0,
  );
}
