import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_lab/engine_profiles.dart';
import 'package:reader_lab/screens/reader_screen.dart';
import 'package:reader_lab/widgets/bookmark_button.dart';

void main() {
  testWidgets('one tap stores a bookmark and a second tap removes it', (tester) async {
    final directory = Directory.systemTemp.createTempSync('reader-lab-screen');
    addTearDown(() => directory.deleteSync(recursive: true));
    final bookmarks = BookmarkStore(File('${directory.path}/bookmarks.json'));
    final positions = PositionStore(File('${directory.path}/positions.json'));
    await bookmarks.load();
    await positions.load();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pump() {
      return tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(
            profile: epubRtlProfile,
            bookId: 'EPUB-001',
            bookTitle: 'Simple Text',
            filePath: 'assets/test_books/EPUB-001-simple.epub',
            bookmarks: bookmarks,
            positions: positions,
          ),
        ),
      );
    }

    await pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.textContaining('ANCHOR-EPUB-001-CH-01'), findsOneWidget);

    final bookmarkIcon = find.descendant(
      of: find.byType(BookmarkButton),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(bookmarkIcon).onPressed, isNotNull);
    await tester.tap(bookmarkIcon);
    await tester.pump();
    expect(bookmarks.items, hasLength(1));
    expect(bookmarks.items.single.location.spineIndex, 0);
    expect(bookmarks.items.single.location.precision, LocationPrecision.exact);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(bookmarkIcon);
    await tester.pump();
    expect(bookmarks.items, isEmpty);
    expect(find.byIcon(Icons.bookmark_border), findsWidgets);
  });
}
