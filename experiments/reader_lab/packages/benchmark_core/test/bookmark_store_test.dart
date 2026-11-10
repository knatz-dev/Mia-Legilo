import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('reader-lab-bookmarks');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Bookmark sample(String id) => Bookmark(
        id: id,
        bookId: 'EPUB-001',
        engineId: 'epub_rtl',
        createdAt: DateTime.utc(2026, 11, 10, 12),
        chapterLabel: 'Chapter 2',
        location: const ReadingLocation(
          engineId: 'epub_rtl',
          precision: LocationPrecision.exact,
          spineIndex: 1,
          nativeLocator: {'element': 0, 'fraction': 0.2},
        ),
      );

  test('one toggle adds and the next toggle removes the same anchor', () async {
    final store = BookmarkStore(File('${directory.path}/bookmarks.json'));
    await store.load();
    final added = await store.toggle(sample('b1'));
    expect(added, isTrue);
    expect(store.items, hasLength(1));

    final reloaded = BookmarkStore(File('${directory.path}/bookmarks.json'));
    await reloaded.load();
    expect(reloaded.items.single.chapterLabel, 'Chapter 2');

    final removed = await reloaded.toggle(sample('b2'));
    expect(removed, isFalse);
    expect(reloaded.items, isEmpty);

    final empty = BookmarkStore(File('${directory.path}/bookmarks.json'));
    await empty.load();
    expect(empty.items, isEmpty);
  });

  test('a different element is a different bookmark', () async {
    final store = BookmarkStore(File('${directory.path}/bookmarks.json'));
    await store.load();
    await store.toggle(sample('b1'));
    final other = Bookmark(
      id: 'b2',
      bookId: 'EPUB-001',
      engineId: 'epub_rtl',
      createdAt: DateTime.utc(2026, 11, 10, 13),
      location: const ReadingLocation(
        engineId: 'epub_rtl',
        precision: LocationPrecision.exact,
        spineIndex: 1,
        nativeLocator: {'element': 3, 'fraction': 0},
      ),
    );
    expect(await store.toggle(other), isTrue);
    expect(store.items, hasLength(2));
  });
}
