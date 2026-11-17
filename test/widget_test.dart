import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mia_legilo/main.dart';

void main() {
  testWidgets('Mia Legilo app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MiaLegiloApp()));
    await tester.pump();
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
