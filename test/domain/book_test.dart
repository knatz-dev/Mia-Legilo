import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/domain/domain.dart';

void main() {
  group('BookAsset', () {
    test('json round trip', () {
      final a = BookAsset(
        bookId: const BookId('b1'),
        localPath: '/data/b1.epub',
        sha256: 'abc123',
        revision: 2,
        importedAt: DateTime.utc(2026, 1, 2),
      );
      expect(BookAsset.fromJson(a.toJson()), equals(a));
    });
  });

  group('Book', () {
    test('json round trip', () {
      final b = Book(
        id: const BookId('b1'),
        title: 'Title',
        authors: const ['Author'],
        readingStatus: ReadingStatus.reading,
        downloadState: DownloadState.downloaded,
        locator: const ReadingLocator(cfi: '/6/4', percentage: 0.5),
        remoteIdentity: const RemoteIdentity(
          providerInstanceId: ProviderInstanceId('p'),
          remoteBookId: RemoteBookId('r'),
        ),
        addedAt: DateTime.utc(2026, 1, 1),
        localAssetPath: '/data/library/abc.epub',
        localAssetSha256: 'abc',
        localAssetRevision: 1,
      );
      expect(Book.fromJson(b.toJson()), equals(b));
    });
  });

  group('Shelf', () {
    test('json round trip', () {
      final s = Shelf(
        id: const ShelfId('s1'),
        name: 'Reading',
        isSystem: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(Shelf.fromJson(s.toJson()), equals(s));
    });
  });

  group('Bookmark', () {
    test('json round trip', () {
      final bm = Bookmark(
        id: const AnnotationId('bm1'),
        bookId: const BookId('b1'),
        locator: const ReadingLocator(anchor: 'ch1'),
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(Bookmark.fromJson(bm.toJson()), equals(bm));
    });
  });
}
