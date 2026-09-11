import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_navigation_scope.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/features/analysis/analysis_screen.dart';
import 'package:smart_property_advisor/features/home/home_screen.dart';
import 'package:smart_property_advisor/models/app_user.dart';
import 'package:smart_property_advisor/models/area_data.dart';

void main() {
  testWidgets('home search launcher is not an editable text field', (
    tester,
  ) async {
    var selectedDestination = -1;
    await _pumpHome(
      tester,
      _homeState(),
      onSelectDestination: (index) => selectedDestination = index,
    );

    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('Search properties, locations, projects...'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    await tester.tap(find.text('Search properties, locations, projects...'));
    await tester.pump();

    expect(selectedDestination, 1);
  });

  testWidgets('trending area requests matching Analysis state and district', (
    tester,
  ) async {
    var selectedDestination = -1;
    final state = _homeState();
    await _pumpHome(
      tester,
      state,
      onSelectDestination: (index) => selectedDestination = index,
    );

    await tester.scrollUntilVisible(
      find.text('Langkawi'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Langkawi'));
    await tester.pump();

    expect(selectedDestination, 4);
    expect(state.requestedAnalysisState, 'Kedah');
    expect(state.requestedAnalysisDistrict, 'Langkawi');
  });

  testWidgets('analysis screen consumes requested state and district', (
    tester,
  ) async {
    final state = _homeState();
    state.requestAnalysisLocation(state: 'Kedah', district: 'Langkawi');

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: const AnalysisScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Langkawi'), findsWidgets);
    expect(find.text('Yan'), findsNothing);
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  AppState state, {
  required ValueChanged<int> onSelectDestination,
}) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: AppNavigationScope(
        selectDestination: onSelectDestination,
        child: MaterialApp(
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: const HomeScreen(),
        ),
      ),
    ),
  );
}

AppState _homeState() {
  final state = AppState();
  state.isLoading = false;
  state.user = const AppUser(
    id: 'demo',
    name: 'Alex Tan',
    email: 'alex@example.com',
  );
  state.areas = const [
    AreaData(
      id: 'kedah_yan',
      name: 'Yan',
      state: 'Kedah',
      priceGrowth: 3.1,
      priceHistory: [240000, 247440],
      marketPricePeriods: ['2026 Q1', '2026 Q2'],
      medianResidentialPrice: 247440,
      marketPriceYear: 2026,
      isGovernmentProfile: true,
    ),
    AreaData(
      id: 'kedah_langkawi',
      name: 'Langkawi',
      state: 'Kedah',
      priceGrowth: 5.4,
      priceHistory: [280000, 295120],
      marketPricePeriods: ['2026 Q1', '2026 Q2'],
      medianResidentialPrice: 295120,
      marketPriceYear: 2026,
      isGovernmentProfile: true,
    ),
  ];
  state.properties = const [];
  return state;
}
