import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app/reader_lab_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  final root = Directory('${directory.path}/reader_lab');
  await root.create(recursive: true);
  final bookmarks = BookmarkStore(File('${root.path}/bookmarks.json'));
  final positions = PositionStore(File('${root.path}/positions.json'));
  await bookmarks.load();
  await positions.load();
  final manifest = CorpusManifest.parse(
    await rootBundle.loadString('assets/test_books/corpus_manifest.json'),
  );
  runApp(
    ReaderLabApp(
      bookmarks: bookmarks,
      positions: positions,
      manifest: manifest,
    ),
  );
}
