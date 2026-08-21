import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/smart_property_advisor_app.dart';

void main() {
  testWidgets('shows the sign in screen', (tester) async {
    await tester.pumpWidget(const SmartPropertyAdvisorApp());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with sample data'), findsOneWidget);
  });
}
