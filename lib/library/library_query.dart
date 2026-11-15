import 'package:mia_legilo/domain/book.dart';
import 'package:mia_legilo/domain/status.dart';

/// Typed, immutable query description for the local library.
enum LibrarySortKey {
  title,
  author,
  added,
  lastRead,
  series,
  progress,
}

enum LibrarySortDirection { ascending, descending }

enum LibraryViewMode { grid, list }

enum LibraryGroupBy {
  none,
  author,
  series,
  status,
  source,
  availability,
}

enum LibrarySourceFilter { all, local, remote }

enum LibraryAvailabilityFilter { all, available, missing }

class LibraryQuery {
  const LibraryQuery({
    this.search,
    this.sort = LibrarySortKey.title,
    this.direction = LibrarySortDirection.ascending,
    this.viewMode = LibraryViewMode.list,
    this.statuses = const <ReadingStatus>{},
    this.groupBy = LibraryGroupBy.none,
    this.sourceFilter = LibrarySourceFilter.all,
    this.availabilityFilter = LibraryAvailabilityFilter.all,
  });

  final String? search;
  final LibrarySortKey sort;
  final LibrarySortDirection direction;
  final LibraryViewMode viewMode;
  final Set<ReadingStatus> statuses;
  final LibraryGroupBy groupBy;
  final LibrarySourceFilter sourceFilter;
  final LibraryAvailabilityFilter availabilityFilter;

  LibraryQuery copyWith({
    String? search,
    LibrarySortKey? sort,
    LibrarySortDirection? direction,
    LibraryViewMode? viewMode,
    Set<ReadingStatus>? statuses,
    LibraryGroupBy? groupBy,
    LibrarySourceFilter? sourceFilter,
    LibraryAvailabilityFilter? availabilityFilter,
    bool clearSearch = false,
  }) =>
      LibraryQuery(
        search: clearSearch ? null : (search ?? this.search),
        sort: sort ?? this.sort,
        direction: direction ?? this.direction,
        viewMode: viewMode ?? this.viewMode,
        statuses: statuses ?? this.statuses,
        groupBy: groupBy ?? this.groupBy,
        sourceFilter: sourceFilter ?? this.sourceFilter,
        availabilityFilter: availabilityFilter ?? this.availabilityFilter,
      );
}

/// Groups a list of books by the requested key.
List<MapEntry<String, List<Book>>> groupBooks(
  List<Book> books,
  LibraryGroupBy groupBy,
) {
  if (groupBy == LibraryGroupBy.none) {
    return <MapEntry<String, List<Book>>>[
      MapEntry<String, List<Book>>('All', books),
    ];
  }
  final Map<String, List<Book>> buckets = <String, List<Book>>{};
  for (final Book book in books) {
    final String key = switch (groupBy) {
      LibraryGroupBy.author =>
        book.authors.isEmpty ? 'Unknown author' : book.authors.first,
      LibraryGroupBy.series => book.series ?? 'Unassigned',
      LibraryGroupBy.status => book.readingStatus.label,
      LibraryGroupBy.source =>
        book.remoteIdentity == null ? 'Local' : 'Remote (CWNG)',
      LibraryGroupBy.availability =>
        book.localAssetPath == null ? 'Missing file' : 'Available',
      LibraryGroupBy.none => 'All',
    };
    buckets.putIfAbsent(key, () => <Book>[]).add(book);
  }
  final List<MapEntry<String, List<Book>>> entries = buckets.entries.toList();
  entries.sort((MapEntry<String, List<Book>> a, MapEntry<String, List<Book>> b) =>
      a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  return entries;
}
