import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/data/app_database.dart';
import 'package:mia_legilo/domain/book.dart' as domain;
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/library/library_query.dart';
import 'package:mia_legilo/library/library_store.dart';

void main() {
  test('library persists across database reopen', () async {
    final Directory dir = await Directory.systemTemp.createTemp('mia_persist_');
    final File file = File('${dir.path}/test.sqlite');
    try {
      AppDatabase db = AppDatabase(NativeDatabase(file));
      final DriftLibraryStore store = DriftLibraryStore(db);
      await store.save(const domain.Book(
        id: BookId('p1'),
        title: 'Persisted One',
        authors: <String>['Author A'],
        localAssetSha256: 'sha1',
        localAssetPath: '/tmp/one.epub',
      ));
      await store.save(const domain.Book(
        id: BookId('p2'),
        title: 'Persisted Two',
        authors: <String>['Author B'],
        localAssetSha256: 'sha2',
      ));
      await store.upsertSearchIndex(const domain.Book(
        id: BookId('p1'),
        title: 'Persisted One',
        authors: <String>['Author A'],
        localAssetSha256: 'sha1',
        localAssetPath: '/tmp/one.epub',
      ));
      await store.upsertSearchIndex(const domain.Book(
        id: BookId('p2'),
        title: 'Persisted Two',
        authors: <String>['Author B'],
        localAssetSha256: 'sha2',
      ));
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final DriftLibraryStore reopened = DriftLibraryStore(db);
      final List<domain.Book> books = await reopened.list();
      expect(books, hasLength(2));
      final List<domain.Book> found = await reopened.query(
        const LibraryQuery(search: 'Persisted'),
      );
      expect(found, hasLength(2));
      await db.close();
    } finally {
      await Future.delayed(const Duration(milliseconds: 200));
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
  });
}
