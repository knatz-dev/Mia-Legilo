import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/core/clock.dart';
import 'package:mia_legilo/domain/book.dart';
import 'package:mia_legilo/library/epub_inspector.dart';
import 'package:mia_legilo/library/library_importer.dart';
import 'package:mia_legilo/library/library_store.dart';

import 'epub_fixtures.dart';

void main() {
  late Directory temp;
  late MemoryLibraryStore store;
  late LibraryImporter importer;
  final FakeClock clock = FakeClock(DateTime.utc(2026, 11, 14, 12));

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mia_import_test_');
    store = MemoryLibraryStore();
    importer = LibraryImporter(
      store: store,
      libraryDirectory: Directory('${temp.path}/library'),
      clock: clock,
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('import', () {
    test('stores content-addressed bytes and metadata', () async {
      final Uint8List bytes = buildEpub(
        opf: standardOpf(title: 'Imported Title', creator: 'Ada Author'),
      );

      final ImportResult result =
          await importer.importBytes(bytes, originalName: 'book.epub');

      expect(result.outcome, ImportOutcome.imported);
      expect(result.book.title, 'Imported Title');
      expect(result.book.authors, <String>['Ada Author']);
      expect(result.book.downloadState, DownloadState.downloaded);
      expect(result.book.addedAt, clock.now());

      final String hash = sha256.convert(bytes).toString();
      expect(result.book.localAssetSha256, hash);
      expect(result.book.localAssetPath, endsWith('$hash.epub'));
      expect(await File(result.book.localAssetPath!).readAsBytes(), bytes);
      expect(result.book.localAssetRevision, 1);

      final List<Book> books = await store.list();
      expect(books, hasLength(1));
      expect(books.single.id, result.book.id);
    });

    test('falls back to the file name when the title is missing', () async {
      final ImportResult result = await importer.importBytes(
        buildEpub(opf: standardOpf(title: '')),
        originalName: 'my_great_book.epub',
      );

      expect(result.book.title, 'my great book');
    });

    test('extracts a cover next to the book', () async {
      final Uint8List cover = Uint8List.fromList(<int>[137, 80, 78, 71, 9]);
      final Uint8List bytes = buildEpub(
        opf: standardOpf(
          coverItem:
              '<item id="c" href="cover.png" media-type="image/png" properties="cover-image"/>',
        ),
        files: <String, List<int>>{'OEBPS/cover.png': cover},
      );

      final ImportResult result =
          await importer.importBytes(bytes, originalName: 'with-cover.epub');

      expect(result.book.coverPath, isNotNull);
      expect(result.book.coverPath, endsWith('.png'));
      expect(await File(result.book.coverPath!).readAsBytes(), cover);
    });

    test('rejects an invalid file without leaving storage behind', () async {
      await expectLater(
        importer.importBytes(
          Uint8List.fromList(<int>[1, 2, 3]),
          originalName: 'broken.epub',
        ),
        throwsA(isA<EpubValidationException>()),
      );

      expect(await store.list(), isEmpty);
      final Directory books = Directory('${temp.path}/library/books');
      expect(await books.exists(), isFalse);
    });
  });

  group('duplicate policy', () {
    test('identical bytes resolve to the existing book', () async {
      final Uint8List bytes = buildEpub();

      final ImportResult first =
          await importer.importBytes(bytes, originalName: 'first.epub');
      final ImportResult second =
          await importer.importBytes(bytes, originalName: 'second.epub');

      expect(second.outcome, ImportOutcome.duplicate);
      expect(second.isDuplicate, isTrue);
      expect(second.book.id, first.book.id);
      expect(await store.list(), hasLength(1));

      final List<FileSystemEntity> stored = await importer.booksDirectory
          .list()
          .where((FileSystemEntity e) => e is File)
          .toList();
      expect(stored, hasLength(1));
    });

    test('different bytes with the same title stay separate books', () async {
      final Uint8List one = buildEpub(
        opf: standardOpf(title: 'Same Name', creator: 'Same Author'),
      );
      final Uint8List two = buildEpub(
        opf: standardOpf(title: 'Same Name', creator: 'Same Author'),
        files: <String, List<int>>{
          'OEBPS/chapter1.xhtml': '<html><body>different</body></html>'.codeUnits,
        },
      );

      final ImportResult first =
          await importer.importBytes(one, originalName: 'a.epub');
      final ImportResult second =
          await importer.importBytes(two, originalName: 'b.epub');

      expect(first.book.id, isNot(second.book.id));
      expect(second.outcome, ImportOutcome.imported);
      expect(await store.list(), hasLength(2));
    });

    test('restores a missing asset for an existing fingerprint', () async {
      final Uint8List bytes = buildEpub();
      final ImportResult first =
          await importer.importBytes(bytes, originalName: 'book.epub');
      await File(first.book.localAssetPath!).delete();

      final ImportResult repaired =
          await importer.importBytes(bytes, originalName: 'book.epub');

      expect(repaired.outcome, ImportOutcome.imported);
      expect(repaired.message, contains('Restored'));
      expect(repaired.book.localAssetRevision, 2);
      expect(await File(repaired.book.localAssetPath!).exists(), isTrue);
      expect(await store.list(), hasLength(1));
    });
  });
}
