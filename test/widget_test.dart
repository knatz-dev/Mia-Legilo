import 'package:flutter_test/flutter_test.dart';

import 'package:mia_legilo/main.dart';

void main() {
  testWidgets('Mia Legilo app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MiaLegiloApp());
    expect(find.text('Mia Legilo'), findsOneWidget);
  });
}
