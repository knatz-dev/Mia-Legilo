import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/domain/book.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/library/library_query.dart';
import 'package:mia_legilo/library/library_store.dart';

void main() {
  test('query performance stays under 2 seconds for 5000 books', () async {
    final MemoryLibraryStore store = MemoryLibraryStore();
    final Random random = Random(42);
    for (int i = 0; i < 5000; i++) {
      await store.save(Book(
        id: BookId('b$i'),
        title: 'Book ${random.nextInt(1000)} number $i',
        authors: <String>['Author ${random.nextInt(200)}'],
        series: i.isEven ? 'Series ${random.nextInt(50)}' : null,
        seriesIndex: i.isEven ? (i % 10) + 1.0 : null,
        description: 'A description for book $i with some searchable words',
        addedAt: DateTime.utc(2026, 1, 1).add(Duration(days: random.nextInt(365))),
        progressPercentage: random.nextDouble(),
        localAssetSha256: 'sha$i',
        localAssetPath: '/tmp/$i.epub',
      ));
    }

    final Stopwatch search = Stopwatch()..start();
    final List<Book> searchResult = await store.query(
      const LibraryQuery(search: 'searchable', sort: LibrarySortKey.title),
    );
    search.stop();
    expect(searchResult, isNotEmpty);
    expect(search.elapsedMilliseconds, lessThan(2000));

    final Stopwatch sort = Stopwatch()..start();
    final List<Book> sorted = await store.query(
      const LibraryQuery(sort: LibrarySortKey.series, direction: LibrarySortDirection.descending),
    );
    sort.stop();
    expect(sorted, hasLength(5000));
    expect(sort.elapsedMilliseconds, lessThan(2000));
  });
}
