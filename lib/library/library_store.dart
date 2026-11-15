import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart' as data;
import '../domain/annotation.dart';
import '../domain/book.dart' as domain;
import '../domain/ids.dart';
import '../domain/locator.dart';
import '../domain/provenance.dart';
import '../domain/status.dart';
import '../library/library_query.dart';

/// Persistence boundary used by the import pipeline.
///
/// Keeping this an interface lets import/duplicate-policy tests run without a
/// native SQLite binary.
abstract class LibraryStore {
  Future<domain.Book?> findById(BookId id);

  /// Identity-based duplicate lookup. Fingerprints are the only local
  /// duplicate signal; titles and authors are never used to merge.
  Future<domain.Book?> findByFingerprint(String sha256);

  Future<void> save(domain.Book book);

  Future<List<domain.Book>> list({bool includeHidden = false});

  /// Mutate the latest row atomically, preserving unrelated user state.
  Future<domain.Book> update(
    BookId id,
    domain.Book Function(domain.Book) change,
  );

  Future<void> removeLocalImport(BookId id, {required bool deleteReadingData});

  Future<void> delete(BookId id);

  /// Typed query against the local library.
  Future<List<domain.Book>> query(LibraryQuery query);

  Future<String?> readSetting(String key);

  Future<void> writeSetting(String key, String value);

  /// Keeps the full-text index in sync with the books table.
  Future<void> upsertSearchIndex(domain.Book book);

  Future<void> removeSearchIndex(String bookId);

  Future<List<Bookmark>> bookmarksFor(BookId bookId);

  Future<void> saveBookmark(Bookmark bookmark);

  Future<void> deleteBookmark(AnnotationId id);
}

class DriftLibraryStore implements LibraryStore {
  DriftLibraryStore(this.database);

  final data.AppDatabase database;

  @override
  Future<domain.Book> update(
    BookId id,
    domain.Book Function(domain.Book) change,
  ) => database.transaction(() async {
    final current = await findById(id);
    if (current == null) throw StateError('Book no longer exists.');
    final updated = change(current);
    await save(updated);
    return updated;
  });

  @override
  Future<void> removeLocalImport(
    BookId id, {
    required bool deleteReadingData,
  }) => database.transaction(() async {
    final current = await findById(id);
    if (current == null) return;
    if (current.remoteIdentity != null)
      throw StateError('This is not a local import.');
    await save(
      current.copyWith(
        hiddenFromLibrary: true,
        clearReadingData: deleteReadingData,
        shelfIds: deleteReadingData ? [] : null,
      ),
    );
    if (deleteReadingData) {
      await (database.delete(
        database.annotations,
      )..where((t) => t.bookId.equals(id.value))).go();
    }
  });

  @override
  Future<domain.Book?> findById(BookId id) async {
    final data.Book? row = await (database.select(
      database.books,
    )..where((t) => t.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.Book?> findByFingerprint(String sha256) async {
    final data.Book? row =
        await (database.select(database.books)
              ..where((t) => t.localAssetSha256.equals(sha256))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(domain.Book book) async {
    await database.into(database.books).insertOnConflictUpdate(_toRow(book));
  }

  @override
  Future<List<domain.Book>> list({bool includeHidden = false}) async {
    final List<data.Book> rows =
        await (database.select(database.books)
              ..where(
                (t) => includeHidden
                    ? const Constant(true)
                    : t.hiddenFromLibrary.equals(false),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.title)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> delete(BookId id) async {
    await (database.delete(
      database.books,
    )..where((t) => t.id.equals(id.value))).go();
    await removeSearchIndex(id.value);
  }

  @override
  Future<List<domain.Book>> query(LibraryQuery query) async {
    List<String>? matchingIds;
    final String? search = query.search?.trim();
    if (search != null && search.isNotEmpty) {
      final String term = _ftsTerm(search);
      try {
        final List<QueryRow> rows = await database
            .customSelect(
              'SELECT book_id FROM books_fts WHERE books_fts MATCH ?',
              variables: [Variable.withString(term)],
            )
            .get();
        matchingIds = rows
            .map((QueryRow r) => r.read<String>('book_id'))
            .toList();
      } catch (_) {
        matchingIds = null;
      }
    }

    var sel = database.select(database.books)
      ..where((t) => t.hiddenFromLibrary.equals(false));
    if (query.authors.isNotEmpty) {
      final authors = query.authors.where((a) => a.isNotEmpty).toList();
      final placeholders = authors.isEmpty
          ? 'NULL'
          : List.filled(authors.length, '?').join(',');
      final rows = await database
          .customSelect(
            "SELECT id FROM books WHERE EXISTS (SELECT 1 FROM json_each(books.authors) WHERE trim(value) IN ($placeholders))"
            "${query.authors.contains('') ? " OR NOT EXISTS (SELECT 1 FROM json_each(books.authors) WHERE trim(value) <> '')" : ''}",
            variables: authors.map(Variable.withString).toList(),
          )
          .get();
      sel.where((t) => t.id.isIn(rows.map((r) => r.read<String>('id'))));
    }
    if (query.series.isNotEmpty) {
      sel.where(
        (t) =>
            const CustomExpression<String>("trim(coalesce(series, ''))")
                .isIn(query.series),
      );
    }
    if (query.shelfIds.isNotEmpty) {
      final rows = await database
          .customSelect(
            "SELECT DISTINCT books.id FROM books, json_each(books.shelf_ids) AS shelf WHERE json_extract(shelf.value, '\$.value') IN (${List.filled(query.shelfIds.length, '?').join(',')})",
            variables: query.shelfIds.map(Variable.withString).toList(),
          )
          .get();
      sel.where((t) => t.id.isIn(rows.map((r) => r.read<String>('id'))));
    }
    if (matchingIds != null) {
      if (matchingIds.isEmpty) return <domain.Book>[];
      sel.where((t) => t.id.isIn(matchingIds!));
    } else if (search != null && search.isNotEmpty) {
      final String like = '%${search.toLowerCase()}%';
      sel.where(
        (t) =>
            t.title.lower().like(like) |
            t.authors.lower().like(like) |
            t.series.lower().like(like) |
            t.description.lower().like(like),
      );
    }

    if (query.statuses.isNotEmpty) {
      sel.where(
        (t) => t.readingStatus.isIn(
          query.statuses.map((ReadingStatus s) => s.name).toList(),
        ),
      );
    }
    switch (query.sourceFilter) {
      case LibrarySourceFilter.local:
        sel.where((t) => t.remoteProviderInstanceId.isNull());
        break;
      case LibrarySourceFilter.remote:
        sel.where((t) => t.remoteProviderInstanceId.isNotNull());
        break;
      case LibrarySourceFilter.all:
        break;
    }
    switch (query.availabilityFilter) {
      case LibraryAvailabilityFilter.available:
        sel.where((t) => t.localAssetPath.isNotNull());
        break;
      case LibraryAvailabilityFilter.missing:
        sel.where((t) => t.localAssetPath.isNull());
        break;
      case LibraryAvailabilityFilter.all:
        break;
    }

    final OrderingMode mode = query.direction == LibrarySortDirection.ascending
        ? OrderingMode.asc
        : OrderingMode.desc;
    sel.orderBy([
      if (query.sort == LibrarySortKey.title)
        (t) => OrderingTerm(mode: mode, expression: t.title),
      if (query.sort == LibrarySortKey.author)
        (t) => OrderingTerm(
          mode: mode,
          expression: CustomExpression<String>(
            "json_extract(authors, '\$[0]')",
          ),
        ),
      if (query.sort == LibrarySortKey.added)
        (t) => OrderingTerm(mode: mode, expression: t.addedAt),
      if (query.sort == LibrarySortKey.lastRead)
        (t) => OrderingTerm(mode: mode, expression: t.lastReadAt),
      if (query.sort == LibrarySortKey.series) ...[
        (t) => OrderingTerm(mode: mode, expression: t.series),
        (t) => OrderingTerm(mode: OrderingMode.asc, expression: t.seriesIndex),
      ],
      if (query.sort == LibrarySortKey.status)
        (t) => OrderingTerm(mode: mode, expression: t.readingStatus),
      if (query.sort == LibrarySortKey.progress)
        (t) => OrderingTerm(mode: mode, expression: t.progressPercentage),
      (t) => OrderingTerm(mode: OrderingMode.asc, expression: t.id),
    ]);

    final List<data.Book> rows = await sel.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<String?> readSetting(String key) async {
    final data.Setting? row = await (database.select(
      database.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    await database
        .into(database.settings)
        .insertOnConflictUpdate(
          data.SettingsCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> upsertSearchIndex(domain.Book book) async {
    await removeSearchIndex(book.id.value);
    await database.customStatement(
      'INSERT INTO books_fts (book_id, title, authors, series, description) VALUES (?, ?, ?, ?, ?)',
      <Object?>[
        book.id.value,
        book.title,
        book.authors.join(' '),
        book.series ?? '',
        book.description ?? '',
      ],
    );
  }

  @override
  Future<void> removeSearchIndex(String bookId) async {
    await database.customStatement(
      'DELETE FROM books_fts WHERE book_id = ?',
      <Object?>[bookId],
    );
  }

  @override
  Future<List<Bookmark>> bookmarksFor(BookId bookId) async {
    final List<data.Annotation> rows =
        await (database.select(database.annotations)
              ..where((t) => t.bookId.equals(bookId.value))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows
        .map(
          (data.Annotation r) => Bookmark(
            id: AnnotationId(r.id),
            bookId: BookId(r.bookId),
            locator: ReadingLocator.fromJson(
              jsonDecode(r.locator) as Map<String, dynamic>,
            ),
            label: r.label,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveBookmark(Bookmark bookmark) async {
    await database
        .into(database.annotations)
        .insertOnConflictUpdate(
          data.AnnotationsCompanion.insert(
            id: bookmark.id.value,
            bookId: bookmark.bookId.value,
            locator: jsonEncode(bookmark.locator.toJson()),
            label: Value(bookmark.label),
            createdAt: Value(bookmark.createdAt),
          ),
        );
  }

  @override
  Future<void> deleteBookmark(AnnotationId id) async {
    await (database.delete(
      database.annotations,
    )..where((t) => t.id.equals(id.value))).go();
  }

  String _ftsTerm(String input) {
    final List<String> tokens = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty)
        .map((String t) => '"${t.replaceAll('"', '""')}"*')
        .toList();
    return tokens.isEmpty ? '""' : tokens.join(' ');
  }

  data.BooksCompanion _toRow(domain.Book book) => data.BooksCompanion.insert(
    id: book.id.value,
    title: book.title,
    authors: Value(jsonEncode(book.authors)),
    series: Value(book.series),
    seriesIndex: Value(book.seriesIndex),
    description: Value(book.description),
    coverPath: Value(book.coverPath),
    readingStatus: Value(book.readingStatus.name),
    readingStatusManual: Value(book.readingStatusManual),
    hiddenFromLibrary: Value(book.hiddenFromLibrary),
    locator: Value(
      book.locator == null ? null : jsonEncode(book.locator!.toJson()),
    ),
    remoteProviderInstanceId: Value(
      book.remoteIdentity?.providerInstanceId.value,
    ),
    remoteBookId: Value(book.remoteIdentity?.remoteBookId.value),
    downloadState: Value(book.downloadState.name),
    localAssetPath: Value(book.localAssetPath),
    localAssetSha256: Value(book.localAssetSha256),
    localAssetRevision: Value(book.localAssetRevision),
    shelfIds: Value(
      jsonEncode(book.shelfIds.map((ShelfId s) => s.toJson()).toList()),
    ),
    addedAt: Value(book.addedAt),
    lastReadAt: Value(book.lastReadAt),
    progressPercentage: Value(book.progressPercentage),
    metadataProvenance: Value(book.metadataProvenance.name),
  );

  domain.Book _toDomain(data.Book row) => domain.Book(
    id: BookId(row.id),
    title: row.title,
    authors: (jsonDecode(row.authors) as List<dynamic>).cast<String>(),
    series: row.series,
    seriesIndex: row.seriesIndex,
    description: row.description,
    coverPath: row.coverPath,
    readingStatus: ReadingStatus.values.firstWhere(
      (ReadingStatus s) => s.name == row.readingStatus,
      orElse: () => ReadingStatus.unread,
    ),
    readingStatusManual: row.readingStatusManual,
    hiddenFromLibrary: row.hiddenFromLibrary,
    locator: row.locator == null
        ? null
        : ReadingLocator.fromJson(
            jsonDecode(row.locator!) as Map<String, dynamic>,
          ),
    remoteIdentity:
        row.remoteProviderInstanceId == null || row.remoteBookId == null
        ? null
        : RemoteIdentity(
            providerInstanceId: ProviderInstanceId(
              row.remoteProviderInstanceId!,
            ),
            remoteBookId: RemoteBookId(row.remoteBookId!),
          ),
    downloadState: domain.DownloadState.values.firstWhere(
      (domain.DownloadState s) => s.name == row.downloadState,
      orElse: () => domain.DownloadState.notDownloaded,
    ),
    localAssetId: row.localAssetPath == null ? null : BookId('asset:${row.id}'),
    localAssetPath: row.localAssetPath,
    localAssetSha256: row.localAssetSha256,
    localAssetRevision: row.localAssetRevision,
    shelfIds: (jsonDecode(row.shelfIds) as List<dynamic>)
        .map((dynamic e) => ShelfId.fromJson(e as Map<String, dynamic>))
        .toList(),
    addedAt: row.addedAt,
    lastReadAt: row.lastReadAt,
    progressPercentage: row.progressPercentage,
    metadataProvenance: MetadataProvenance.values.firstWhere(
      (MetadataProvenance p) => p.name == row.metadataProvenance,
      orElse: () => MetadataProvenance.standard,
    ),
  );
}

/// In-memory store for import-policy tests and previews.
class MemoryLibraryStore implements LibraryStore {
  final Map<String, domain.Book> _books = <String, domain.Book>{};
  final Map<String, String> _settings = <String, String>{};
  final List<Bookmark> _bookmarks = <Bookmark>[];

  @override
  Future<domain.Book> update(
    BookId id,
    domain.Book Function(domain.Book) change,
  ) async {
    final current = _books[id.value];
    if (current == null) throw StateError('Book no longer exists.');
    final updated = change(current);
    _books[id.value] = updated;
    return updated;
  }

  @override
  Future<void> removeLocalImport(
    BookId id, {
    required bool deleteReadingData,
  }) async {
    await update(id, (current) {
      if (current.remoteIdentity != null)
        throw StateError('This is not a local import.');
      return current.copyWith(
        hiddenFromLibrary: true,
        clearReadingData: deleteReadingData,
        shelfIds: deleteReadingData ? [] : null,
      );
    });
    if (deleteReadingData) _bookmarks.removeWhere((b) => b.bookId == id);
  }

  @override
  Future<domain.Book?> findById(BookId id) async => _books[id.value];

  @override
  Future<domain.Book?> findByFingerprint(String sha256) async {
    for (final domain.Book book in _books.values) {
      if (book.localAssetSha256 == sha256) return book;
    }
    return null;
  }

  @override
  Future<void> save(domain.Book book) async {
    _books[book.id.value] = book;
  }

  @override
  Future<List<domain.Book>> list({bool includeHidden = false}) async {
    final List<domain.Book> books = _books.values
        .where((b) => includeHidden || !b.hiddenFromLibrary)
        .toList();
    books.sort(
      (domain.Book a, domain.Book b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }

  @override
  Future<void> delete(BookId id) async {
    _books.remove(id.value);
  }

  @override
  Future<List<domain.Book>> query(LibraryQuery query) async {
    Iterable<domain.Book> result = _books.values.where(
      (b) => !b.hiddenFromLibrary,
    );
    if (query.authors.isNotEmpty)
      result = result.where((b) => authorValues(b).any(query.authors.contains));
    if (query.series.isNotEmpty)
      result = result.where(
        (b) => query.series.contains((b.series ?? '').trim()),
      );
    if (query.shelfIds.isNotEmpty)
      result = result.where(
        (b) => b.shelfIds.any((s) => query.shelfIds.contains(s.value)),
      );
    final String? search = query.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      result = result.where(
        (domain.Book b) =>
            b.title.toLowerCase().contains(search) ||
            b.authors.join(' ').toLowerCase().contains(search) ||
            (b.series?.toLowerCase().contains(search) ?? false) ||
            (b.description?.toLowerCase().contains(search) ?? false),
      );
    }
    if (query.statuses.isNotEmpty) {
      result = result.where(
        (domain.Book b) => query.statuses.contains(b.readingStatus),
      );
    }
    switch (query.sourceFilter) {
      case LibrarySourceFilter.local:
        result = result.where((domain.Book b) => b.remoteIdentity == null);
        break;
      case LibrarySourceFilter.remote:
        result = result.where((domain.Book b) => b.remoteIdentity != null);
        break;
      case LibrarySourceFilter.all:
        break;
    }
    switch (query.availabilityFilter) {
      case LibraryAvailabilityFilter.available:
        result = result.where((domain.Book b) => b.localAssetPath != null);
        break;
      case LibraryAvailabilityFilter.missing:
        result = result.where((domain.Book b) => b.localAssetPath == null);
        break;
      case LibraryAvailabilityFilter.all:
        break;
    }
    final List<domain.Book> sorted = result.toList();
    int cmp(domain.Book a, domain.Book b) {
      int r;
      switch (query.sort) {
        case LibrarySortKey.title:
          r = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case LibrarySortKey.author:
          r = (a.authors.isEmpty ? '' : a.authors.first.toLowerCase())
              .compareTo(
                b.authors.isEmpty ? '' : b.authors.first.toLowerCase(),
              );
          break;
        case LibrarySortKey.added:
          r = (a.addedAt ?? DateTime(0)).compareTo(b.addedAt ?? DateTime(0));
          break;
        case LibrarySortKey.lastRead:
          r = (a.lastReadAt ?? DateTime(0)).compareTo(
            b.lastReadAt ?? DateTime(0),
          );
          break;
        case LibrarySortKey.series:
          r = (a.series ?? '').toLowerCase().compareTo(
            (b.series ?? '').toLowerCase(),
          );
          if (r == 0) {
            r = (a.seriesIndex ?? 0).compareTo(b.seriesIndex ?? 0);
          }
          break;
        case LibrarySortKey.status:
          r = a.readingStatus.name.compareTo(b.readingStatus.name);
          break;
        case LibrarySortKey.progress:
          r = (a.progressPercentage ?? 0).compareTo(b.progressPercentage ?? 0);
          break;
      }
      if (r == 0) return a.id.value.compareTo(b.id.value);
      return query.direction == LibrarySortDirection.ascending ? r : -r;
    }

    sorted.sort(cmp);
    return sorted;
  }

  @override
  Future<String?> readSetting(String key) async => _settings[key];

  @override
  Future<void> writeSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<List<Bookmark>> bookmarksFor(BookId bookId) async =>
      _bookmarks.where((Bookmark b) => b.bookId == bookId).toList();

  @override
  Future<void> saveBookmark(Bookmark bookmark) async {
    _bookmarks.removeWhere((Bookmark b) => b.id == bookmark.id);
    _bookmarks.add(bookmark);
  }

  @override
  Future<void> deleteBookmark(AnnotationId id) async {
    _bookmarks.removeWhere((Bookmark b) => b.id == id);
  }

  @override
  Future<void> upsertSearchIndex(domain.Book book) async {}

  @override
  Future<void> removeSearchIndex(String bookId) async {}
}
