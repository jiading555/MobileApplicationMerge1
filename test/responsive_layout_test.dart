import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/core/utils/responsive_layout.dart';

void main() {
  testWidgets('classifies portrait phone as phone only', (tester) async {
    await _pumpWithSize(tester, const Size(407, 904));

    final context = tester.element(find.byType(SizedBox));

    expect(ResponsiveLayout.isPhone(context), isTrue);
    expect(ResponsiveLayout.isTablet(context), isFalse);
    expect(ResponsiveLayout.isDesktop(context), isFalse);
  });

  testWidgets('keeps wide landscape phone out of desktop mode', (tester) async {
    await _pumpWithSize(tester, const Size(1100, 430));

    final context = tester.element(find.byType(SizedBox));

    expect(ResponsiveLayout.isPhone(context), isTrue);
    expect(ResponsiveLayout.isTablet(context), isFalse);
    expect(ResponsiveLayout.isDesktop(context), isFalse);
    expect(ResponsiveLayout.isCompactLandscapePhone(context), isTrue);
    expect(ResponsiveLayout.usesSideNavigation(context), isTrue);
  });

  testWidgets('classifies tablet as tablet but not desktop', (tester) async {
    await _pumpWithSize(tester, const Size(900, 700));

    final context = tester.element(find.byType(SizedBox));

    expect(ResponsiveLayout.isPhone(context), isFalse);
    expect(ResponsiveLayout.isTablet(context), isTrue);
    expect(ResponsiveLayout.isDesktop(context), isFalse);
    expect(ResponsiveLayout.usesSideNavigation(context), isTrue);
  });

  testWidgets('classifies large viewport as desktop', (tester) async {
    await _pumpWithSize(tester, const Size(1200, 800));

    final context = tester.element(find.byType(SizedBox));

    expect(ResponsiveLayout.isPhone(context), isFalse);
    expect(ResponsiveLayout.isTablet(context), isTrue);
    expect(ResponsiveLayout.isDesktop(context), isTrue);
  });
}

Future<void> _pumpWithSize(WidgetTester tester, Size logicalSize) async {
  await tester.binding.setSurfaceSize(logicalSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: logicalSize),
        child: const SizedBox.shrink(),
      ),
    ),
  );
}
