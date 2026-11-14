import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart' as data;
import '../domain/book.dart' as domain;
import '../domain/ids.dart';
import '../domain/locator.dart';
import '../domain/provenance.dart';
import '../domain/status.dart';

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

  Future<List<domain.Book>> list();

  Future<void> delete(BookId id);
}

class DriftLibraryStore implements LibraryStore {
  DriftLibraryStore(this.database);

  final data.AppDatabase database;

  @override
  Future<domain.Book?> findById(BookId id) async {
    final data.Book? row = await (database.select(database.books)
          ..where(($BooksTable t) => t.id.equals(id.value)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<domain.Book?> findByFingerprint(String sha256) async {
    final data.Book? row = await (database.select(database.books)
          ..where(($BooksTable t) => t.localAssetSha256.equals(sha256))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(domain.Book book) async {
    await database.into(database.books).insertOnConflictUpdate(_toRow(book));
  }

  @override
  Future<List<domain.Book>> list() async {
    final List<data.Book> rows = await (database.select(database.books)
          ..orderBy(<OrderClauseGenerator<$BooksTable>>[
            ($BooksTable t) => OrderingTerm.asc(t.title),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> delete(BookId id) async {
    await (database.delete(database.books)
          ..where(($BooksTable t) => t.id.equals(id.value)))
        .go();
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
        locator: Value(book.locator == null ? null : jsonEncode(book.locator!.toJson())),
        remoteProviderInstanceId: Value(book.remoteIdentity?.providerInstanceId.value),
        remoteBookId: Value(book.remoteIdentity?.remoteBookId.value),
        downloadState: Value(book.downloadState.name),
        localAssetPath: Value(book.localAssetPath),
        localAssetSha256: Value(book.localAssetSha256),
        localAssetRevision: Value(book.localAssetRevision),
        shelfIds: Value(jsonEncode(book.shelfIds.map((ShelfId s) => s.toJson()).toList())),
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
        locator: row.locator == null
            ? null
            : ReadingLocator.fromJson(
                jsonDecode(row.locator!) as Map<String, dynamic>),
        remoteIdentity: row.remoteProviderInstanceId == null ||
                row.remoteBookId == null
            ? null
            : RemoteIdentity(
                providerInstanceId:
                    ProviderInstanceId(row.remoteProviderInstanceId!),
                remoteBookId: RemoteBookId(row.remoteBookId!),
              ),
        downloadState: domain.DownloadState.values.firstWhere(
          (domain.DownloadState s) => s.name == row.downloadState,
          orElse: () => domain.DownloadState.notDownloaded,
        ),
        localAssetId:
            row.localAssetPath == null ? null : BookId('asset:${row.id}'),
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
  Future<List<domain.Book>> list() async {
    final List<domain.Book> books = _books.values.toList();
    books.sort((domain.Book a, domain.Book b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return books;
  }

  @override
  Future<void> delete(BookId id) async {
    _books.remove(id.value);
  }
}
