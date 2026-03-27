import 'package:flutter_test/flutter_test.dart';
import 'package:foragecast/main.dart';

void main() {
  testWidgets('App renders safety gate on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(const ForageCastApp());
    await tester.pumpAndSettle();

    // Safety gate should show "Before you begin"
    expect(find.text('Before you begin'), findsOneWidget);
    expect(find.text('I understand'), findsOneWidget);
  });
}
