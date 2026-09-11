import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_navigation_scope.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_shell.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/features/analysis/analysis_screen.dart';
import 'package:smart_property_advisor/features/home/home_screen.dart';
import 'package:smart_property_advisor/models/app_user.dart';
import 'package:smart_property_advisor/models/area_data.dart';

void main() {
  testWidgets('Home removes redundant search launcher across layouts', (
    tester,
  ) async {
    for (final size in [
      const Size(390, 844),
      const Size(844, 390),
      const Size(1024, 768),
    ]) {
      await _pumpShell(tester, size);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Search properties, locations, projects...'),
        findsNothing,
      );
      expect(find.text('Find Property'), findsOneWidget);
      expect(find.text('App hub'), findsOneWidget);
    }
  });

  testWidgets('Find Property opens the Search tab from Home', (tester) async {
    await _pumpShell(tester, const Size(390, 844));

    await tester.tap(find.text('Find Property'));
    await tester.pumpAndSettle();

    expect(find.text('Property search'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
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

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final state = _homeState();
  state.properties = const [];
  state.areas = const [];

  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(size: size),
          child: child!,
        ),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
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
  state.isAuthenticated = true;
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
