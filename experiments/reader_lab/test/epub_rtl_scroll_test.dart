import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_lab/engines/epub_rtl/epub_rtl_view.dart';
import 'package:benchmark_core/benchmark_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EpubRtlHandle? handle;

  Future<void> pumpBook(
    WidgetTester tester,
    String filename, {
    ReadingLocation? initial,
    ReaderPreferences preferences = const ReaderPreferences(),
  }) async {
    handle = null;
    final path = 'assets/test_books/$filename';
    expect(File(path).existsSync(), isTrue, reason: 'Run scripts/generate_corpus.py');
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: EpubRtlView(
          filePath: path,
          preferences: preferences,
          initialLocation: initial,
          onLocation: (_) {},
          onChapterLabel: (_) {},
          onHandle: (value) => handle = value,
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  }

  testWidgets('short chapters share one vertical scroll view', (tester) async {
    await pumpBook(tester, 'EPUB-007-short-chapters.epub');
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.textContaining('ANCHOR-EPUB-007-CH-01'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('ANCHOR-EPUB-007-CH-20'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.textContaining('ANCHOR-EPUB-007-CH-20'), findsOneWidget);
  });

  testWidgets('scrolling up reaches an earlier chapter without a chapter button', (
    tester,
  ) async {
    await pumpBook(tester, 'EPUB-007-short-chapters.epub');
    final pending = handle!.navigate(
      const ReadingLocation(
        engineId: 'epub_rtl',
        precision: LocationPrecision.exact,
        spineIndex: 20,
        nativeLocator: {'element': 0, 'fraction': 0},
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    await pending;
    expect(find.textContaining('ANCHOR-EPUB-007-CH-21'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('ANCHOR-EPUB-007-CH-16'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.textContaining('ANCHOR-EPUB-007-CH-16'), findsOneWidget);
  });

  testWidgets('display none stays out of the scroll text', (tester) async {
    await pumpBook(tester, 'EPUB-004-css.epub');
    expect(find.textContaining('ANCHOR-EPUB-004-CH-01'), findsOneWidget);
    expect(find.textContaining('HIDDEN-EPUB-004-SHOULD-NOT-APPEAR'), findsNothing);
    expect(find.textContaining('TABLE-CELL-EPUB-005'), findsNothing);
  });

  testWidgets('restores the same block after a larger font', (tester) async {
    await pumpBook(
      tester,
      'EPUB-007-short-chapters.epub',
      initial: const ReadingLocation(
        engineId: 'epub_rtl',
        precision: LocationPrecision.exact,
        spineIndex: 12,
        nativeLocator: {'element': 0, 'fraction': 0},
      ),
    );
    expect(find.textContaining('ANCHOR-EPUB-007-CH-13'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: EpubRtlView(
          filePath: 'assets/test_books/EPUB-007-short-chapters.epub',
          preferences: ReaderPreferences(fontSize: 28, lineHeight: 2),
          initialLocation: ReadingLocation(
            engineId: 'epub_rtl',
            precision: LocationPrecision.exact,
            spineIndex: 12,
            nativeLocator: {'element': 0, 'fraction': 0},
          ),
          onLocation: _noop,
          onChapterLabel: _noopLabel,
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.textContaining('ANCHOR-EPUB-007-CH-13'), findsOneWidget);
  });

  testWidgets('mixed content renders the table cell', (tester) async {
    await pumpBook(tester, 'EPUB-005-mixed.epub');
    expect(find.textContaining('TABLE-CELL-EPUB-005'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}

void _noop(ReadingLocation _) {}

void _noopLabel(String _) {}
