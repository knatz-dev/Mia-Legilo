import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mia_legilo/library/library_service.dart';
import 'package:mia_legilo/main.dart';

void main() {
  testWidgets('Mia Legilo app builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // The real database needs platform channels a test binding lacks.
          libraryProvider.overrideWith(
            (Ref ref) => Future<LibraryService>.value(
              LibraryService.bootstrap(),
            ),
          ),
        ],
        child: const MiaLegiloApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
