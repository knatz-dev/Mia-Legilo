import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/clock.dart';
import '../domain/book.dart' as domain;
import '../domain/ids.dart';
import '../domain/provenance.dart';
import 'epub_inspector.dart';
import 'library_store.dart';

enum ImportOutcome { imported, duplicate }

/// Result of an import attempt. [book] is always the canonical library entry:
/// the newly inserted one, or the existing entry a duplicate resolved to.
class ImportResult {
  const ImportResult({
    required this.outcome,
    required this.book,
    required this.metadata,
    required this.message,
  });

  final ImportOutcome outcome;
  final domain.Book book;
  final EpubMetadata metadata;
  final String message;

  bool get isDuplicate => outcome == ImportOutcome.duplicate;
}

/// Imports EPUB bytes into app-private, content-addressed storage.
///
/// Duplicate policy: a book's local identity is the SHA-256 fingerprint of its
/// source bytes. Re-importing identical bytes returns the existing entry and
/// does not create a second file or row. Different bytes always produce a
/// different book, even with identical title/author metadata.
class LibraryImporter {
  LibraryImporter({
    required this.store,
    required Directory libraryDirectory,
    this.inspector = const EpubInspector(),
    this.clock = const SystemClock(),
  }) : root = libraryDirectory;

  final LibraryStore store;
  final EpubInspector inspector;
  final Clock clock;
  final Directory root;

  Directory get booksDirectory => Directory(p.join(root.path, 'books'));
  Directory get coversDirectory => Directory(p.join(root.path, 'covers'));
  Directory get stagingDirectory => Directory(p.join(root.path, '.tmp'));

  static const int maxImportBytes = EpubInspector.maxArchiveBytes;

  /// Imports a file chosen through the system picker (SAF) or found on disk.
  Future<ImportResult> importFile(File file, {String? originalName}) async {
    final int length = await file.length();
    if (length > maxImportBytes) {
      throw const EpubValidationException(
        EpubRejection.archiveTooLarge,
        'The file is larger than the 512 MB import limit.',
      );
    }
    final Uint8List bytes = await file.readAsBytes();
    return importBytes(
      bytes,
      originalName: originalName ?? p.basename(file.path),
    );
  }

  Future<ImportResult> importBytes(
    Uint8List bytes, {
    required String originalName,
  }) async {
    final String sha256 = _fingerprint(bytes);
    final domain.Book? existing = await store.findByFingerprint(sha256);
    if (existing != null) {
      final ImportResult? repaired = await _repairIfMissing(existing, bytes);
      if (repaired != null) return repaired;
      return ImportResult(
        outcome: ImportOutcome.duplicate,
        book: existing,
        metadata: await _inspectQuietly(existing, bytes),
        message: '"${existing.title}" is already in your library.',
      );
    }

    final EpubMetadata metadata = inspector.inspectBytes(bytes);
    final String title = metadata.title.trim().isEmpty
        ? _fallbackTitle(originalName)
        : metadata.title.trim();

    await _ensureDirectories();
    final File asset = File(p.join(booksDirectory.path, '$sha256.epub'));
    final bool assetCreated = await _promote(
      bytes,
      asset,
      stagingName: '$sha256.epub.part',
    );

    String? coverPath;
    if (metadata.coverBytes != null && metadata.coverExtension != null) {
      final File cover = File(
        p.join(coversDirectory.path, '$sha256${metadata.coverExtension!}'),
      );
      await _promote(
        metadata.coverBytes!,
        cover,
        stagingName: '$sha256.cover.part',
      );
      coverPath = cover.path;
    }

    final domain.Book book = domain.Book(
      id: BookId('local:$sha256'),
      title: title,
      authors: metadata.authors,
      series: metadata.series,
      seriesIndex: metadata.seriesIndex,
      description: metadata.description,
      coverPath: coverPath,
      downloadState: domain.DownloadState.downloaded,
      localAssetId: BookId('asset:$sha256'),
      localAssetPath: asset.path,
      localAssetSha256: sha256,
      localAssetRevision: 1,
      addedAt: clock.now(),
      metadataProvenance: MetadataProvenance.standard,
    );

    try {
      await store.save(book);
      await store.upsertSearchIndex(book);
    } catch (e) {
      // Keep the promoted file when a previous identical import may have
      // created it; deleting a content-addressed file is only safe when this
      // call created it and no row references it.
      if (assetCreated) {
        try {
          await asset.delete();
        } catch (_) {
          // Cleanup is best effort; the next import rewrites the same path.
        }
      }
      rethrow;
    }

    return ImportResult(
      outcome: ImportOutcome.imported,
      book: book,
      metadata: metadata,
      message: 'Imported "$title".',
    );
  }

  /// Recreates a missing asset for an existing row. Returns null when the file
  /// is present, so the caller reports a plain duplicate.
  Future<ImportResult?> _repairIfMissing(
    domain.Book existing,
    Uint8List bytes,
  ) async {
    final String? path = existing.localAssetPath;
    if (path != null && await File(path).exists()) return null;

    final EpubMetadata metadata = inspector.inspectBytes(bytes);
    await _ensureDirectories();
    final String sha256 = existing.localAssetSha256 ?? _fingerprint(bytes);
    final File asset = File(p.join(booksDirectory.path, '$sha256.epub'));
    await _promote(bytes, asset, stagingName: '$sha256.epub.part');

    String? coverPath = existing.coverPath;
    if (metadata.coverBytes != null && metadata.coverExtension != null) {
      final File cover = File(
        p.join(coversDirectory.path, '$sha256${metadata.coverExtension!}'),
      );
      await _promote(
        metadata.coverBytes!,
        cover,
        stagingName: '$sha256.cover.part',
      );
      coverPath = cover.path;
    }

    final domain.Book repaired = existing.copyWith(
      localAssetPath: asset.path,
      localAssetSha256: sha256,
      localAssetRevision: (existing.localAssetRevision ?? 1) + 1,
      coverPath: coverPath,
      downloadState: domain.DownloadState.downloaded,
    );
    await store.save(repaired);
    await store.upsertSearchIndex(repaired);
    return ImportResult(
      outcome: ImportOutcome.imported,
      book: repaired,
      metadata: metadata,
      message: 'Restored the missing file for "${existing.title}".',
    );
  }

  Future<EpubMetadata> _inspectQuietly(
    domain.Book book,
    Uint8List bytes,
  ) async {
    try {
      return inspector.inspectBytes(bytes);
    } catch (_) {
      // The bytes were valid when first imported; fall back to stored fields.
      return EpubMetadata(
        title: book.title,
        authors: book.authors,
        spineCount: 0,
        series: book.series,
        seriesIndex: book.seriesIndex,
        description: book.description,
      );
    }
  }

  /// Writes [bytes] to a staging file in the same filesystem and renames it
  /// into place, so a crash never leaves a half-written library asset.
  /// Returns true when this call created the destination.
  Future<bool> _promote(
    Uint8List bytes,
    File target, {
    required String stagingName,
  }) async {
    if (await target.exists()) return false;
    final File staging = File(p.join(stagingDirectory.path, stagingName));
    await staging.writeAsBytes(bytes, flush: true);
    try {
      await staging.rename(target.path);
      return true;
    } on FileSystemException {
      // Another import may have promoted the same content concurrently.
      if (await target.exists()) {
        await staging.delete();
        return false;
      }
      rethrow;
    }
  }

  Future<void> _ensureDirectories() async {
    for (final Directory directory in <Directory>[
      root,
      booksDirectory,
      coversDirectory,
      stagingDirectory,
    ]) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  String _fingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

  String _fallbackTitle(String originalName) {
    final String withoutExtension = p.basenameWithoutExtension(originalName);
    final String cleaned = withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return cleaned.isEmpty ? 'Untitled' : cleaned;
  }

  /// Replaces the on-disk asset of an existing book without changing its id.
  Future<domain.Book> relink(domain.Book existing, Uint8List bytes, {
    String originalName = 'book.epub',
  }) async {
    final EpubMetadata metadata = inspector.inspectBytes(bytes);
    final String sha256 = _fingerprint(bytes);
    await _ensureDirectories();
    final File asset = File(p.join(booksDirectory.path, '$sha256.epub'));
    await _promote(bytes, asset, stagingName: '$sha256.epub.part');

    String? coverPath = existing.coverPath;
    if (metadata.coverBytes != null && metadata.coverExtension != null) {
      final File cover = File(
        p.join(coversDirectory.path, '$sha256${metadata.coverExtension!}'),
      );
      await _promote(
        metadata.coverBytes!,
        cover,
        stagingName: '$sha256.cover.part',
      );
      coverPath = cover.path;
    }

    final domain.Book updated = existing.copyWith(
      title: metadata.title.trim().isEmpty ? existing.title : metadata.title.trim(),
      authors: metadata.authors.isEmpty ? existing.authors : metadata.authors,
      series: metadata.series ?? existing.series,
      seriesIndex: metadata.seriesIndex ?? existing.seriesIndex,
      description: metadata.description ?? existing.description,
      coverPath: coverPath,
      downloadState: domain.DownloadState.downloaded,
      localAssetPath: asset.path,
      localAssetSha256: sha256,
      localAssetRevision: (existing.localAssetRevision ?? 0) + 1,
    );
    await store.save(updated);
    await store.upsertSearchIndex(updated);
    return updated;
  }

  /// Extracts a cover from the stored EPUB if the book has none.
  Future<domain.Book> ensureCover(domain.Book book) async {
    if (book.coverPath != null && File(book.coverPath!).existsSync()) {
      return book;
    }
    if (book.localAssetPath == null) return book;
    final Uint8List bytes = await File(book.localAssetPath!).readAsBytes();
    final EpubMetadata metadata;
    try {
      metadata = inspector.inspectBytes(bytes);
    } catch (_) {
      return book;
    }
    if (metadata.coverBytes == null || metadata.coverExtension == null) {
      return book;
    }
    await _ensureDirectories();
    final String sha256 = book.localAssetSha256 ?? _fingerprint(bytes);
    final File cover = File(
      p.join(coversDirectory.path, '$sha256${metadata.coverExtension!}'),
    );
    await _promote(
      metadata.coverBytes!,
      cover,
      stagingName: '$sha256.cover.part',
    );
    final domain.Book updated = book.copyWith(coverPath: cover.path);
    await store.save(updated);
    await store.upsertSearchIndex(updated);
    return updated;
  }
}
