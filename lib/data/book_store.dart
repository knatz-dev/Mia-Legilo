import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Discovers EPUB files the reader can open.
///
/// The first accessible candidate wins:
/// 1. the app's external files directory — `Android/data/<app id>/files/books`,
///    so books can be dropped in with `adb push` during development;
/// 2. the app documents directory — survives scoped-storage restrictions;
/// 3. the app support directory.
class BookStore {
  BookStore(this.directory);

  final Directory directory;

  static Future<BookStore> open() async {
    for (final Directory base in await _candidateBases()) {
      final Directory books = Directory(p.join(base.path, 'books'));
      try {
        if (!await books.exists()) await books.create(recursive: true);
        // Probing the listing surfaces scoped-storage denials here rather than
        // on the first shelf refresh.
        await books.list().toList();
        return BookStore(books);
      } catch (e) {
        // ignore: avoid_print
        print('BookStore: ${books.path} unusable ($e)');
      }
    }
    throw const FileSystemException('No readable book directory available');
  }

  static Future<List<Directory>> _candidateBases() async {
    final List<Directory> bases = <Directory>[];
    try {
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) bases.add(external);
    } catch (_) {
      // Not available on this platform.
    }
    try {
      bases.add(await getApplicationDocumentsDirectory());
    } catch (_) {
      // Not available on this platform.
    }
    try {
      bases.add(await getApplicationSupportDirectory());
    } catch (_) {
      // Not available on this platform.
    }
    return bases;
  }

  /// EPUB files on the shelf, ordered by file name.
  Future<List<File>> list() async {
    if (!await directory.exists()) return <File>[];
    final List<File> files = await directory
        .list()
        .where((FileSystemEntity entity) =>
            entity is File && entity.path.toLowerCase().endsWith('.epub'))
        .cast<File>()
        .toList();
    files.sort((File a, File b) => p.basename(a.path).toLowerCase().compareTo(
          p.basename(b.path).toLowerCase(),
        ));
    return files;
  }
}
