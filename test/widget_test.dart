import 'package:flutter_test/flutter_test.dart';
import 'package:parklagbee/app/app.dart';

void main() {
  testWidgets('ParkLagbee smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ParkLagbeeApp());

    // Verify splash screen elements ("PARK" and "Lagbee")
    expect(find.text('PARK'), findsOneWidget);
    expect(find.text('Lagbee'), findsOneWidget);

    // Pump timer to complete splash animation
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
