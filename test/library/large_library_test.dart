import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/domain/book.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/domain/status.dart';
import 'package:mia_legilo/library/library_query.dart';
import 'package:mia_legilo/library/library_store.dart';

void main() {
  group('large library', () {
    test('10k books: search + filter + sort + group under 3s', () async {
      final MemoryLibraryStore store = MemoryLibraryStore();
      final Random random = Random(7);
      for (int i = 0; i < 10000; i++) {
        await store.save(Book(
          id: BookId('b$i'),
          title: i % 5 == 0 ? 'Duplicate Title' : 'Book title $i',
          authors: i % 3 == 0 ? <String>[] : <String>['Author ${random.nextInt(500)}'],
          series: i % 4 == 0 ? 'Series ${random.nextInt(20)}' : null,
          seriesIndex: i % 4 == 0 ? (i % 9) + 1.0 : null,
          description: i % 2 == 0 ? 'searchable keyword alpha' : null,
          readingStatus: ReadingStatus.values[random.nextInt(ReadingStatus.values.length)],
          addedAt: random.nextBool()
              ? DateTime.utc(2026, 1, 1).add(Duration(days: random.nextInt(365)))
              : null,
          progressPercentage: random.nextBool() ? random.nextDouble() : null,
          localAssetPath: random.nextBool() ? '/tmp/$i.epub' : null,
          localAssetSha256: 'sha$i',
          remoteIdentity: random.nextBool()
              ? null
              : null, // keep all local for determinism
        ));
      }

      final Stopwatch sw = Stopwatch()..start();
      final List<Book> result = await store.query(const LibraryQuery(
        search: 'searchable',
        statuses: <ReadingStatus>{ReadingStatus.reading, ReadingStatus.completed},
        sourceFilter: LibrarySourceFilter.local,
        availabilityFilter: LibraryAvailabilityFilter.available,
        sort: LibrarySortKey.series,
        direction: LibrarySortDirection.descending,
        groupBy: LibraryGroupBy.author,
      ));
      sw.stop();
      // sanity: some results
      expect(result, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: '10k query took ${sw.elapsedMilliseconds}ms');

      // duplicate titles remain distinct books
      final List<Book> dupes = await store.query(
        const LibraryQuery(search: 'Duplicate Title'),
      );
      expect(dupes.length, greaterThan(1));
      final Set<String> ids = dupes.map((Book b) => b.id.value).toSet();
      expect(ids.length, dupes.length);
    });

    test('null metadata does not break sorting or grouping', () async {
      final MemoryLibraryStore store = MemoryLibraryStore();
      await store.save(const Book(
        id: BookId('n1'),
        title: 'Zeta',
        authors: <String>[],
        localAssetSha256: 'a',
        localAssetPath: '/tmp/a.epub',
      ));
      await store.save(const Book(
        id: BookId('n2'),
        title: 'Alpha',
        authors: <String>[],
        localAssetSha256: 'b',
      ));
      final List<Book> byAuthor = await store.query(
        const LibraryQuery(sort: LibrarySortKey.author),
      );
      expect(byAuthor, hasLength(2));
      final List<MapEntry<String, List<Book>>> groups =
          groupBooks(byAuthor, LibraryGroupBy.author);
      expect(groups, isNotEmpty);
    });
  });
}
