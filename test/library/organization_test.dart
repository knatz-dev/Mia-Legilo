import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/data/app_database.dart';
import 'package:mia_legilo/domain/book.dart' as domain;
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/domain/locator.dart';
import 'package:mia_legilo/domain/status.dart';
import 'package:mia_legilo/integrations/cwng/cwng_auth.dart';
import 'package:mia_legilo/integrations/cwng/token_store.dart';
import 'package:mia_legilo/library/library_importer.dart';
import 'package:mia_legilo/library/library_query.dart';
import 'package:mia_legilo/library/library_service.dart';
import 'package:mia_legilo/library/library_store.dart';
import 'package:mia_legilo/library/resumable_downloader.dart';

import 'epub_fixtures.dart';

void main() {
  for (final databaseBacked in [false, true]) {
    group(databaseBacked ? 'Drift organization' : 'memory organization', () {
      late LibraryStore store;
      late LibraryService library;
      late Directory root;
      AppDatabase? database;
      setUp(() async {
        root = await Directory.systemTemp.createTemp('organization_');
        if (databaseBacked) database = AppDatabase(NativeDatabase.memory());
        store = databaseBacked ? DriftLibraryStore(database!) : MemoryLibraryStore();
        library = LibraryService(store: store, importer: LibraryImporter(store: store, libraryDirectory: root),
          downloader: ResumableDownloader(), root: root);
      });
      tearDown(() async {
        await database?.close();
        await root.delete(recursive: true);
      });

      test('AND dimensions, OR values, exact authors including quotes, missing metadata', () async {
        const books = [
          domain.Book(id: BookId('one'), title: 'Alpha', authors: ['Ada', "O'Brien"], series: 'Saga',
            shelfIds: [ShelfId('favourites')], readingStatus: ReadingStatus.reading, localAssetPath: 'one.epub'),
          domain.Book(id: BookId('two'), title: 'Alpha', authors: ['Bea'], series: 'Saga', readingStatus: ReadingStatus.completed),
          domain.Book(id: BookId('three'), title: 'Alpha', authors: [' ']),
          domain.Book(id: BookId('four'), title: 'Other', authors: ['Ada'], series: 'Saga',
            remoteIdentity: RemoteIdentity(providerInstanceId: ProviderInstanceId('remote'), remoteBookId: RemoteBookId('one'))),
        ];
        for (final book in books) { await store.save(book); await store.upsertSearchIndex(book); }
        const query = LibraryQuery(search: 'Alpha', authors: {"O'Brien", 'Bea'}, series: {'Saga'},
          statuses: {ReadingStatus.reading, ReadingStatus.completed}, sourceFilter: LibrarySourceFilter.local,
          sort: LibrarySortKey.title, direction: LibrarySortDirection.descending, groupBy: LibraryGroupBy.author);
        expect((await store.query(query)).map((b) => b.id.value), ['one', 'two']);
        expect((await store.query(query.copyWith(shelfIds: {'favourites', 'other'}, availabilityFilter: LibraryAvailabilityFilter.available))).single.id, const BookId('one'));
        expect((await store.query(const LibraryQuery(authors: {''}, series: {''}))).single.id, const BookId('three'));
        expect(await store.query(const LibraryQuery(authors: {"' OR 1=1 --"})), isEmpty);
        expect(await store.query(query.clearFilters()), hasLength(4));
        expect(LibraryQuery.fromJson(jsonDecode(jsonEncode(query.toJson())) as Map<String, dynamic>).toJson(), query.toJson());
      });

      test('automatic start requires activity; manual status wins concurrent progress', () async {
        const id = BookId('state');
        await store.save(const domain.Book(id: id, title: 'State', readingStatus: ReadingStatus.wantToRead));
        await library.recordProgress(id, const ReadingLocator(percentage: .1), meaningful: false);
        expect((await store.findById(id))!.readingStatus, ReadingStatus.wantToRead);
        await library.recordProgress(id, const ReadingLocator(percentage: .2), meaningful: true);
        expect((await store.findById(id))!.readingStatus, ReadingStatus.reading);
        await Future.wait([
          library.recordProgress(id, const ReadingLocator(cfi: 'final', percentage: .8), meaningful: true),
          library.setStatus(id, ReadingStatus.onHold),
        ]);
        var book = (await store.findById(id))!;
        expect(book.readingStatus, ReadingStatus.onHold);
        expect(book.readingStatusManual, isTrue);
        expect(book.locator!.cfi, 'final');
        for (final status in ReadingStatus.values) {
          await library.setStatus(id, status);
          await library.recordProgress(id, const ReadingLocator(percentage: .9), meaningful: true);
          book = (await store.findById(id))!;
          expect(book.readingStatus, status);
          expect(book.downloadState, domain.DownloadState.notDownloaded);
        }
      });

      test('automation disabled and completion prompt dismissal persists', () async {
        const id = BookId('auto');
        await store.save(const domain.Book(id: id, title: 'Auto'));
        await store.writeSetting('library.autoStartReading', 'false');
        await library.recordProgress(id, const ReadingLocator(percentage: 1), meaningful: true);
        expect((await store.findById(id))!.readingStatus, ReadingStatus.unread);
        expect(await library.claimCompletionPrompt(id), isTrue);
        expect(await library.claimCompletionPrompt(id), isFalse);
        expect((await store.findById(id))!.readingStatus, ReadingStatus.unread);
      });

      test('remove download preserves state and reimport repairs same identity', () async {
        final bytes = buildEpub();
        final book = (await library.importBytes(bytes, name: 'test.epub')).book;
        await library.setStatus(book.id, ReadingStatus.completed);
        await library.recordProgress(book.id, const ReadingLocator(cfi: 'anchor', percentage: .8), meaningful: true);
        await library.addBookmark(book.id, const ReadingLocator(cfi: 'bookmark'));
        final removed = await library.removeDownload(book.id);
        expect(removed.localAssetPath, isNull);
        expect(removed.downloadState, domain.DownloadState.removed);
        expect(removed.readingStatus, ReadingStatus.completed);
        expect(removed.locator!.cfi, 'anchor');
        expect(await library.bookmarksFor(book.id), hasLength(1));
        expect(await File(book.localAssetPath!).exists(), isFalse);
        expect(await library.books(), hasLength(1));
        final restored = (await library.importBytes(bytes, name: 'again.epub')).book;
        expect(restored.id, book.id);
        expect(restored.readingStatus, ReadingStatus.completed);
        expect(await File(restored.localAssetPath!).exists(), isTrue);
      });

      test('shared files are retained and external source deletion is refused', () async {
        final shared = File('${root.path}/shared.epub');
        await shared.writeAsString('content');
        await store.save(domain.Book(id: const BookId('a'), title: 'A', localAssetPath: shared.path));
        await store.save(domain.Book(id: const BookId('b'), title: 'B', localAssetPath: shared.path, hiddenFromLibrary: true));
        await library.removeDownload(const BookId('a'));
        expect(await shared.exists(), isTrue);
        final outside = await Directory.systemTemp.createTemp('outside_');
        try {
          final file = File('${outside.path}/source.epub');
          await file.writeAsString('source');
          await store.save(domain.Book(id: const BookId('external'), title: 'External', localAssetPath: file.path));
          await expectLater(library.removeDownload(const BookId('external')), throwsStateError);
          expect(await file.exists(), isTrue);
          expect((await store.findById(const BookId('external')))!.localAssetPath, file.path);
        } finally { await outside.delete(recursive: true); }
      });

      test('remove import explicitly retains or purges data; automatic adoption cannot revive it', () async {
        final bytes = buildEpub();
        final book = (await library.importBytes(bytes, name: 'test.epub')).book;
        await library.setStatus(book.id, ReadingStatus.onHold);
        await library.addBookmark(book.id, const ReadingLocator(cfi: 'saved'));
        await library.removeLocalImport(book.id, deleteReadingData: false);
        expect(await library.books(), isEmpty);
        expect(await store.query(const LibraryQuery()), isEmpty);
        expect(await library.adoptExistingFiles(library.importer.booksDirectory), 0);
        expect(await library.books(), isEmpty);
        final restored = (await library.importBytes(bytes, name: 'again.epub')).book;
        expect(restored.readingStatus, ReadingStatus.onHold);
        expect(await library.bookmarksFor(book.id), hasLength(1));
        await library.removeLocalImport(book.id, deleteReadingData: true);
        final reset = (await library.importBytes(bytes, name: 'again.epub')).book;
        expect(reset.readingStatus, ReadingStatus.unread);
        expect(reset.readingStatusManual, isFalse);
        expect(await library.bookmarksFor(book.id), isEmpty);
      });

      test('credential logout preserves offline books, binding and reading data', () async {
        final book = (await library.importBytes(buildEpub(), name: 'remote.epub')).book;
        const identity = RemoteIdentity(providerInstanceId: ProviderInstanceId('server'), remoteBookId: RemoteBookId('42'));
        await store.update(book.id, (b) => b.copyWith(remoteIdentity: identity));
        await library.setStatus(book.id, ReadingStatus.reading);
        await library.addBookmark(book.id, const ReadingLocator(cfi: 'offline'));
        final tokens = InMemoryTokenStore();
        await tokens.write('cwng_access_token', 'test-token');
        await CwngAuthenticator(dio: Dio(), tokenStore: tokens, baseUrl: 'https://example.invalid').logout();
        expect(await tokens.read('cwng_access_token'), isNull);
        expect((await store.findById(book.id))!.remoteIdentity, identity);
        expect((await store.findById(book.id))!.readingStatus, ReadingStatus.reading);
        expect(await File(book.localAssetPath!).exists(), isTrue);
        expect(await library.bookmarksFor(book.id), hasLength(1));
        await expectLater(library.removeLocalImport(book.id, deleteReadingData: true), throwsStateError);
      });
    });
  }

  test('v3 migration and restart preserve data and organization preferences', () async {
    final root = await Directory.systemTemp.createTemp('organization_migration_');
    final file = File('${root.path}/library.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      var store = DriftLibraryStore(db);
      const id = BookId('migrate');
      await store.save(const domain.Book(id: id, title: 'Retained', readingStatus: ReadingStatus.onHold, readingStatusManual: true));
      const query = LibraryQuery(groupBy: LibraryGroupBy.author, authors: {'Ada', ''}, series: {'Saga'}, statuses: {ReadingStatus.onHold}, sourceFilter: LibrarySourceFilter.local);
      await store.writeSetting('library.query', jsonEncode(query.toJson()));
      await db.customStatement('ALTER TABLE books DROP COLUMN hidden_from_library');
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      store = DriftLibraryStore(db);
      expect((await store.list()).single.hiddenFromLibrary, isFalse);
      expect((await store.findById(id))!.readingStatus, ReadingStatus.onHold);
      expect(jsonDecode((await store.readSetting('library.query'))!), query.toJson());
      await store.removeLocalImport(id, deleteReadingData: false);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      store = DriftLibraryStore(db);
      expect(await store.list(), isEmpty);
      expect((await store.findById(id))!.readingStatusManual, isTrue);
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });
}
