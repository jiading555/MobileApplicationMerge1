import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/core/utils/location_normalizer.dart';
import 'package:smart_property_advisor/features/advisor/advisor_screen.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  testWidgets(
    'Advisor exposes property State and Area options without AreaData matches',
    (tester) async {
      final state = AppState();
      state.properties = [
        _teduhProperty(
          id: 'johor_bahru',
          name: 'Residensi Johor Bahru',
          state: 'Johor',
          district: 'Johor Bahru',
          scheme: 'PPAM',
          price: 300000,
          unitTypes: const ['APARTMEN'],
        ),
        _teduhProperty(
          id: 'petaling',
          name: 'Residensi Petaling',
          state: 'Selangor',
          district: 'Petaling',
          scheme: 'Rumah Selangorku',
          price: 350000,
          unitTypes: const ['RUMAH TERES'],
        ),
      ];
      state.areas = const [];

      await _pumpAdvisor(tester, state);

      await _openDropdown(tester, 0);
      expect(find.text('Johor'), findsWidgets);
      expect(find.text('Selangor'), findsWidgets);
      await tester.tap(find.text('Johor').last);
      await tester.pumpAndSettle();

      await _openDropdown(tester, 1);
      expect(find.text('Johor Bahru'), findsWidgets);
      expect(find.text('Petaling'), findsNothing);
      await tester.tap(find.text('Johor Bahru').last);
      await tester.pumpAndSettle();

      await _openDropdown(tester, 2);
      expect(find.text('Apartment / Flat'), findsWidgets);
      await tester.tap(find.text('Apartment / Flat').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Generate matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate matches'));
      await tester.pumpAndSettle();

      expect(state.preferences.preferredState, 'Johor');
      expect(state.preferences.preferredDistrict, 'Johor Bahru');
      expect(state.preferences.preferredAreaId, 'any');
      expect(
        find.text(
          'No listings with valid price data match this area, property type and budget. Try another filter.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Advisor changing State resets incompatible Area selection', (
    tester,
  ) async {
    final state = AppState();
    state.properties = [
      _teduhProperty(
        id: 'johor_bahru',
        name: 'Residensi Johor Bahru',
        state: 'Johor',
        district: 'Johor Bahru',
        scheme: 'PPAM',
        price: 300000,
        unitTypes: const ['APARTMEN'],
      ),
      _teduhProperty(
        id: 'petaling',
        name: 'Residensi Petaling',
        state: 'Selangor',
        district: 'Petaling',
        scheme: 'Rumah Selangorku',
        price: 350000,
        unitTypes: const ['RUMAH TERES'],
      ),
    ];
    state.areas = const [];

    await _pumpAdvisor(tester, state);

    await _openDropdown(tester, 0);
    await tester.tap(find.text('Johor').last);
    await tester.pumpAndSettle();

    await _openDropdown(tester, 1);
    await tester.tap(find.text('Johor Bahru').last);
    await tester.pumpAndSettle();
    expect(find.text('Johor Bahru'), findsOneWidget);

    await _openDropdown(tester, 0);
    await tester.tap(find.text('Selangor').last);
    await tester.pumpAndSettle();

    expect(find.text('Any area'), findsOneWidget);

    await _openDropdown(tester, 1);
    expect(find.text('Petaling'), findsWidgets);
    expect(find.text('Johor Bahru'), findsNothing);
  });
}

Future<void> _pumpAdvisor(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const AdvisorScreen(),
      ),
    ),
  );
}

Future<void> _openDropdown(WidgetTester tester, int index) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
  await tester.pumpAndSettle();
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
      'unit_types': unitTypes,
    },
    areaId: LocationNormalizer.canonicalAreaId(state, district),
    palette: 0,
  );
}
