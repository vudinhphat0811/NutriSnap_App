import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('NutriSnap smoke test - renders initial screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NutriSnapApp());
    await tester.pumpAndSettle();

    // Verify that the NutriSnap app title or branding is rendered.
    expect(find.text('NutriSnap'), findsWidgets);
  });
}
