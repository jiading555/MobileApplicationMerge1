import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_shell.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';

void main() {
  testWidgets('portrait phone uses bottom navigation', (tester) async {
    await _pumpShell(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      find.byKey(const ValueKey('compact-side-navigation')),
      findsOneWidget,
    );
  });

  testWidgets('landscape phone uses scrollable compact side navigation', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(844, 390));

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('compact-side-navigation')),
      findsOneWidget,
    );
    expect(find.byType(ListView), findsWidgets);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('compact side navigation changes destination without overflow', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(844, 390));

    await tester.tap(find.byKey(const ValueKey('compact-nav-Profile')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('compact-nav-Profile')))
          .isSelected,
      isTrue,
    );
  });

  testWidgets('switches through Advisor and Analysis without framework error', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(844, 390));

    await tester.tap(find.byKey(const ValueKey('compact-nav-Advisor')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('compact-nav-Analysis')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('compact-nav-Advisor')));
    await tester.pump();
    expect(tester.takeException(), isNull);
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
