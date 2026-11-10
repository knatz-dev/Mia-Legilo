import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_lab/widgets/bookmark_button.dart';

void main() {
  testWidgets('one tap toggles the icon and does not open a dialog', (tester) async {
    var active = false;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BookmarkButton(
                active: active,
                onPressed: () {
                  taps += 1;
                  setState(() => active = !active);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    await tester.tap(find.byType(BookmarkButton));
    await tester.pump();
    expect(taps, 1);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byType(BookmarkButton));
    await tester.pump();
    expect(taps, 2);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });
}
