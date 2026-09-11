import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/features/profile/profile_screen.dart';
import 'package:smart_property_advisor/models/app_user.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/property.dart';
import 'package:smart_property_advisor/models/user_preferences.dart';

void main() {
  testWidgets('property preferences opens as a draggable content-sized sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = _profileState();
    await _pumpProfile(tester, state);

    await _openPropertyPreferences(tester);

    expect(
      find.text('Set your default budget and property search filters.'),
      findsOneWidget,
    );
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(844 * 0.88),
    );
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(BottomSheet), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(
      find.text('Set your default budget and property search filters.'),
      findsNothing,
    );
    expect(state.preferences.maximumBudget, 900000);
  });

  testWidgets('property preferences sheet fits landscape by scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await _pumpProfile(tester, _profileState());
    await _openPropertyPreferences(tester);

    expect(find.text('Property preferences'), findsWidgets);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThanOrEqualTo(390 * 0.90),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openPropertyPreferences(WidgetTester tester) async {
  final editButton = find.byTooltip('Edit').last;
  await tester.ensureVisible(editButton);
  await tester.pumpAndSettle();
  await tester.tap(editButton);
  await tester.pumpAndSettle();
}

Future<void> _pumpProfile(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const ProfileScreen(),
      ),
    ),
  );
}

AppState _profileState() {
  final state = AppState();
  state.isLoading = false;
  state.isAuthenticated = true;
  state.user = const AppUser(
    id: 'demo',
    name: 'Alex Tan',
    email: 'alex@example.com',
    isDemo: true,
  );
  state.preferences = const UserPreferences(
    preferredState: 'Perak',
    preferredDistrict: 'Kinta',
    propertyType: 'Apartment / Flat',
    minimumBudget: 350000,
    maximumBudget: 900000,
    budget: 900000,
  );
  state.areas = const [
    AreaData(id: 'perak_kinta', name: 'Kinta', state: 'Perak'),
  ];
  state.properties = const [
    Property(
      id: 'property_profile',
      name: 'Residensi Profile',
      areaId: 'perak_kinta',
      address: 'Kinta, Perak',
      type: 'APARTMEN',
      tenure: 'Freehold',
      state: 'Perak',
      district: 'Kinta',
      price: 300000,
      summary: 'Official listing information.',
      facilities: [],
      palette: 0,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      unitTypes: ['APARTMEN'],
    ),
  ];
  return state;
}
