import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_lab/contracts/reader_engine.dart';

void main() {
  test('manifest hashes match the generated epub bytes', () {
    final manifest = CorpusManifest.parse(
      File('assets/test_books/corpus_manifest.json').readAsStringSync(),
    );
    expect(manifest.books, hasLength(8));
    expect(manifest.license, 'CC0-1.0');
    final spines = {for (final book in manifest.books) book.id: book.spineItemCount};
    expect(spines['EPUB-003'], greaterThanOrEqualTo(100));
    expect(spines['EPUB-006'], 2);
    expect(spines['EPUB-007'], greaterThan(10));
    for (final book in manifest.books) {
      final path = 'assets/test_books/${book.filename}';
      final bytes = File(path).readAsBytesSync();
      expect(bytes.length, book.sizeBytes);
      final digest = Process.runSync('sha256sum', [path]);
      expect(digest.exitCode, 0);
      expect(digest.stdout.toString().split(' ').first, book.sha256);
    }
  });

  test('pinned engine versions are the pubspec versions', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('epub_rtl: 0.1.0'));
    expect(pubspec, contains('flutter_epub_viewer: 2.2.1'));
  });

  test('foliate host requests scrolled flow and keeps continuous scroll enabled', () {
    final host = File('assets/foliate/host.html').readAsStringSync();
    expect(host, contains("setAttribute('flow', 'scrolled')"));
    expect(host, contains("removeAttribute('no-continuous-scroll')"));
    expect(host, isNot(contains("setAttribute('no-continuous-scroll'")));
    final pin = File('assets/foliate/PINNED_SHA').readAsStringSync().trim();
    expect(pin, '090ccca6989a904f6df343538902bd8431c5a7a5');
    expect(File('assets/foliate/LICENSE').readAsStringSync(), contains('MIT License'));
    expect(File('assets/foliate/NOTICE').readAsStringSync(), contains('AGPL-3.0'));
  });

  test('capability flags do not pretend every engine exposes CFI', () {
    expect(epubRtlCapability.exposesEpubCfi, isFalse);
    expect(epubRtlCapability.exposesElementOffset, isTrue);
    expect(epubJsCapability.exposesEpubCfi, isTrue);
    expect(epubJsCapability.exposesPercentage, isTrue);
    expect(readiumCapability.exposesEpubCfi, isFalse);
    expect(foliateCapability.scrollMode, contains('scrolled'));
  });
}
