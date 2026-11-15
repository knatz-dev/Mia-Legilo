import '../domain/book.dart';
import '../domain/status.dart';

/// Typed, immutable query description for the local library.
enum LibrarySortKey { title, author, added, lastRead, series, progress, status }

enum LibrarySortDirection { ascending, descending }

enum LibraryViewMode { grid, list }

enum LibraryGroupBy { none, author, series, status, source, availability }

enum LibrarySourceFilter { all, local, remote }

enum LibraryAvailabilityFilter { all, available, missing }

class LibraryQuery {
  const LibraryQuery({
    this.search,
    this.sort = LibrarySortKey.title,
    this.direction = LibrarySortDirection.ascending,
    this.viewMode = LibraryViewMode.list,
    this.statuses = const <ReadingStatus>{},
    this.authors = const <String>{},
    this.series = const <String>{},
    this.shelfIds = const <String>{},
    this.groupBy = LibraryGroupBy.none,
    this.sourceFilter = LibrarySourceFilter.all,
    this.availabilityFilter = LibraryAvailabilityFilter.all,
  });

  final String? search;
  final LibrarySortKey sort;
  final LibrarySortDirection direction;
  final LibraryViewMode viewMode;
  final Set<ReadingStatus> statuses;
  // Empty string represents unknown author or unassigned series.
  final Set<String> authors;
  final Set<String> series;
  final Set<String> shelfIds;
  final LibraryGroupBy groupBy;
  final LibrarySourceFilter sourceFilter;
  final LibraryAvailabilityFilter availabilityFilter;

  bool get hasFilters =>
      (search?.trim().isNotEmpty ?? false) ||
      statuses.isNotEmpty ||
      authors.isNotEmpty ||
      series.isNotEmpty ||
      shelfIds.isNotEmpty ||
      sourceFilter != LibrarySourceFilter.all ||
      availabilityFilter != LibraryAvailabilityFilter.all;

  LibraryQuery copyWith({
    String? search,
    LibrarySortKey? sort,
    LibrarySortDirection? direction,
    LibraryViewMode? viewMode,
    Set<ReadingStatus>? statuses,
    Set<String>? authors,
    Set<String>? series,
    Set<String>? shelfIds,
    LibraryGroupBy? groupBy,
    LibrarySourceFilter? sourceFilter,
    LibraryAvailabilityFilter? availabilityFilter,
    bool clearSearch = false,
  }) => LibraryQuery(
    search: clearSearch ? null : (search ?? this.search),
    sort: sort ?? this.sort,
    direction: direction ?? this.direction,
    viewMode: viewMode ?? this.viewMode,
    statuses: statuses ?? this.statuses,
    authors: authors ?? this.authors,
    series: series ?? this.series,
    shelfIds: shelfIds ?? this.shelfIds,
    groupBy: groupBy ?? this.groupBy,
    sourceFilter: sourceFilter ?? this.sourceFilter,
    availabilityFilter: availabilityFilter ?? this.availabilityFilter,
  );

  LibraryQuery clearFilters() => copyWith(
    clearSearch: true,
    statuses: {},
    authors: {},
    series: {},
    shelfIds: {},
    sourceFilter: LibrarySourceFilter.all,
    availabilityFilter: LibraryAvailabilityFilter.all,
  );

  Map<String, dynamic> toJson() => {
    'search': search,
    'sort': sort.name,
    'direction': direction.name,
    'viewMode': viewMode.name,
    'groupBy': groupBy.name,
    'sourceFilter': sourceFilter.name,
    'availabilityFilter': availabilityFilter.name,
    'statuses': statuses.map((s) => s.name).toList(),
    'authors': authors.toList(),
    'series': series.toList(),
    'shelfIds': shelfIds.toList(),
  };

  factory LibraryQuery.fromJson(Map<String, dynamic> json) => LibraryQuery(
    search: json['search'] as String?,
    sort: _enumValue(LibrarySortKey.values, json['sort'], LibrarySortKey.title),
    direction: _enumValue(
      LibrarySortDirection.values,
      json['direction'],
      LibrarySortDirection.ascending,
    ),
    viewMode: _enumValue(
      LibraryViewMode.values,
      json['viewMode'],
      LibraryViewMode.list,
    ),
    groupBy: _enumValue(
      LibraryGroupBy.values,
      json['groupBy'],
      LibraryGroupBy.none,
    ),
    sourceFilter: _enumValue(
      LibrarySourceFilter.values,
      json['sourceFilter'],
      LibrarySourceFilter.all,
    ),
    availabilityFilter: _enumValue(
      LibraryAvailabilityFilter.values,
      json['availabilityFilter'],
      LibraryAvailabilityFilter.all,
    ),
    statuses: ReadingStatus.values
        .where((s) => _strings(json['statuses']).contains(s.name))
        .toSet(),
    authors: _strings(json['authors']),
    series: _strings(json['series']),
    shelfIds: _strings(json['shelfIds']),
  );
}

T _enumValue<T extends Enum>(List<T> values, dynamic name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);
Set<String> _strings(dynamic value) =>
    value is List ? value.whereType<String>().toSet() : {};

Set<String> authorValues(Book book) {
  final values = book.authors
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toSet();
  return values.isEmpty ? {''} : values;
}

/// Each multi-author book appears once per author; overall totals use the input.
List<MapEntry<String, List<Book>>> groupBooks(
  List<Book> books,
  LibraryGroupBy groupBy,
) {
  if (groupBy == LibraryGroupBy.none) return [MapEntry('All', books)];
  final buckets = <String, List<Book>>{};
  for (final book in books) {
    final Set<String> keys = switch (groupBy) {
      LibraryGroupBy.author => authorValues(
        book,
      ).map((a) => a.isEmpty ? 'Unknown author' : a).toSet(),
      LibraryGroupBy.series => {
        (book.series?.trim().isNotEmpty ?? false)
            ? book.series!.trim()
            : 'Unassigned',
      },
      LibraryGroupBy.status => {book.readingStatus.label},
      LibraryGroupBy.source => {
        book.remoteIdentity == null ? 'Local' : 'Remote (CWNG)',
      },
      LibraryGroupBy.availability => {
        book.localAssetPath == null ? 'Missing file' : 'Available',
      },
      LibraryGroupBy.none => {'All'},
    };
    for (final key in keys) {
      buckets.putIfAbsent(key, () => <Book>[]).add(book);
    }
  }
  final entries = buckets.entries.toList();
  entries.sort((a, b) {
    final comparison = a.key.toLowerCase().compareTo(b.key.toLowerCase());
    return comparison == 0 ? a.key.compareTo(b.key) : comparison;
  });
  return entries;
}
