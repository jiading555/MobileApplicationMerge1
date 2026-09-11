import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_shell.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';

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
}

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final state = AppState();
  state.isLoading = false;
  state.isAuthenticated = true;
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
