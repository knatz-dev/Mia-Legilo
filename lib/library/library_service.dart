import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/clock.dart';
import '../data/app_database.dart' as data;
import '../data/book_store.dart';
import '../data/database_factory.dart';
import '../domain/annotation.dart';
import '../domain/book.dart';
import '../domain/ids.dart';
import '../domain/locator.dart';
import '../domain/status.dart';
import 'library_importer.dart';
import 'library_store.dart';
import 'resumable_downloader.dart';

/// Application-facing library facade: one place that owns the database,
/// content-addressed storage, imports and downloads.
class LibraryService {
  LibraryService({
    required this.store,
    required this.importer,
    required this.downloader,
    required this.root,
    this.clock = const SystemClock(),
    this.closeDatabase,
  });

  final LibraryStore store;
  final LibraryImporter importer;
  final ResumableDownloader downloader;
  final Directory root;
  final Clock clock;
  final Future<void> Function()? closeDatabase;

  Directory get downloadDirectory => Directory(p.join(root.path, 'downloads'));

  static Future<LibraryService> open({
    LibraryStore? store,
    LibraryImporter? importer,
    ResumableDownloader? downloader,
  }) async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory root = Directory(p.join(documents.path, 'library'));
    final data.AppDatabase? database = store == null
        ? await openAppDatabase()
        : null;
    final LibraryStore resolvedStore = store ?? DriftLibraryStore(database!);
    return LibraryService(
      store: resolvedStore,
      importer:
          importer ??
          LibraryImporter(store: resolvedStore, libraryDirectory: root),
      downloader: downloader ?? ResumableDownloader(),
      root: root,
      closeDatabase: database == null ? null : () => database.close(),
    );
  }

  Future<List<Book>> books() => store.list();

  Future<Book> setStatus(BookId id, ReadingStatus status) => store.update(
    id,
    (book) => book.copyWith(readingStatus: status, readingStatusManual: true),
  );

  Future<bool> autoStartEnabled() async =>
      await store.readSetting('library.autoStartReading') != 'false';

  Future<void> recordProgress(
    BookId id,
    ReadingLocator locator, {
    required bool meaningful,
  }) async {
    final autoStart = await autoStartEnabled();
    await store.update(
      id,
      (book) => book.copyWith(
        locator: locator,
        progressPercentage: locator.percentage,
        lastReadAt: clock.now(),
        readingStatus:
            meaningful &&
                autoStart &&
                !book.readingStatusManual &&
                (book.readingStatus == ReadingStatus.unread ||
                    book.readingStatus == ReadingStatus.wantToRead)
            ? ReadingStatus.reading
            : book.readingStatus,
      ),
    );
  }

  Future<bool> claimCompletionPrompt(BookId id) async {
    final book = await store.findById(id);
    if (book == null ||
        book.readingStatus == ReadingStatus.completed ||
        book.readingStatusManual) {
      return false;
    }
    final key =
        'reader.completionPrompted:${id.value}:${book.localAssetRevision ?? 0}';
    if (await store.readSetting(key) == 'true') return false;
    await store.writeSetting(key, 'true');
    return true;
  }

  Future<Book> removeDownload(BookId id) async {
    final book = await store.findById(id);
    if (book == null) throw StateError('Book no longer exists.');
    final path = book.localAssetPath;
    if (path != null) {
      final shared = (await store.list(includeHidden: true))
          .any((other) => other.id != id && other.localAssetPath == path);
      if (!shared) {
        final file = File(path);
        // Only app-managed copies may be removed, never an external source.
        final managedRoot = await root.resolveSymbolicLinks();
        if (await file.exists()) {
          final resolved = await file.resolveSymbolicLinks();
          if (!p.isWithin(managedRoot, resolved)) {
            throw StateError('File is outside app-managed storage.');
          }
          await file.delete();
        }
      }
    }
    return store.update(
      id,
      (current) => current.copyWith(
        clearLocalAsset: true,
        downloadState: DownloadState.removed,
      ),
    );
  }

  Future<void> removeLocalImport(
    BookId id, {
    required bool deleteReadingData,
  }) => store.removeLocalImport(id, deleteReadingData: deleteReadingData);

  Future<Book?> bookById(String id) => store.findById(BookId(id));

  Future<ImportResult> importFile(File file, {String? originalName}) async =>
      importer.importFile(file, originalName: originalName);

  Future<Book> relinkBook(Book book, File file) async => importer.relink(
    book,
    await file.readAsBytes(),
    originalName: p.basename(file.path),
  );

  Future<Book> ensureCover(Book book) => importer.ensureCover(book);

  Future<List<Bookmark>> bookmarksFor(BookId id) => store.bookmarksFor(id);

  Future<void> addBookmark(
    BookId bookId,
    ReadingLocator locator, {
    String? label,
  }) => store.saveBookmark(
    Bookmark(
      id: AnnotationId('bm-${DateTime.now().microsecondsSinceEpoch}'),
      bookId: bookId,
      locator: locator,
      label: label,
      createdAt: DateTime.now(),
    ),
  );

  Future<void> deleteBookmark(AnnotationId id) => store.deleteBookmark(id);

  Future<ImportResult> importBytes(
    List<int> bytes, {
    required String name,
  }) async => importer.importBytes(
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    originalName: name,
  );

  /// Downloads [uri] into staging, validates it by importing, and removes the
  /// staging copy once the content-addressed library asset exists.
  Future<ImportResult> importUrl(
    Uri uri, {
    void Function(DownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final Directory staging = downloadDirectory;
    if (!await staging.exists()) await staging.create(recursive: true);
    final File target = File(p.join(staging.path, suggestedDownloadName(uri)));
    final File downloaded = await downloader.download(
      uri,
      target: target,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    try {
      return await importer.importFile(
        downloaded,
        originalName: suggestedDownloadName(uri),
      );
    } finally {
      // The importer keeps its own content-addressed copy.
      try {
        if (await downloaded.exists()) await downloaded.delete();
      } catch (_) {
        // Staging leftovers are harmless; the next import overwrites them.
      }
    }
  }

  /// Registers EPUB files that were dropped into the development shelf folder
  /// (for example with `adb push`) but are not in the database yet.
  ///
  /// Returns the number of newly adopted books. Invalid files are skipped and
  /// reported through [onError] rather than aborting the whole scan.
  Future<int> adoptExistingFiles(
    Directory source, {
    void Function(File file, Object error)? onError,
  }) async {
    if (!await source.exists()) return 0;
    int adopted = 0;
    await for (final FileSystemEntity entity in source.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.epub')) {
        continue;
      }
      try {
        final ImportResult result = await importer.importFile(
          entity,
          restoreHidden: false,
        );
        if (result.outcome == ImportOutcome.imported) adopted++;
      } catch (e) {
        onError?.call(entity, e);
      }
    }
    return adopted;
  }

  /// Convenience used at startup: adopts files from the legacy shelf folder.
  Future<int> adoptDeviceShelf() async {
    try {
      final BookStore shelf = await BookStore.open();
      return await adoptExistingFiles(shelf.directory);
    } catch (_) {
      return 0;
    }
  }

  Future<void> close() async {
    await closeDatabase?.call();
  }
}
