import 'ids.dart';

/// Immutable source-content asset for a book (DATA-001).
///
/// Source EPUB bytes are immutable; revisions track replacement, and the
/// SHA-256 fingerprint enables integrity checks and anchor-migration review.
class BookAsset {
  const BookAsset({
    required this.bookId,
    required this.localPath,
    required this.sha256,
    required this.revision,
    required this.importedAt,
    this.immutable = true,
  });

  final BookId bookId;
  final String localPath;
  final String sha256;
  final int revision;
  final DateTime importedAt;
  final bool immutable;

  BookAsset copyWith({
    String? localPath,
    String? sha256,
    int? revision,
    DateTime? importedAt,
    bool? immutable,
  }) =>
      BookAsset(
        bookId: bookId,
        localPath: localPath ?? this.localPath,
        sha256: sha256 ?? this.sha256,
        revision: revision ?? this.revision,
        importedAt: importedAt ?? this.importedAt,
        immutable: immutable ?? this.immutable,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bookId': bookId.toJson(),
        'localPath': localPath,
        'sha256': sha256,
        'revision': revision,
        'importedAt': importedAt.toIso8601String(),
        'immutable': immutable,
      };

  factory BookAsset.fromJson(Map<String, dynamic> json) => BookAsset(
        bookId: BookId.fromJson(json['bookId'] as Map<String, dynamic>),
        localPath: json['localPath'] as String,
        sha256: json['sha256'] as String,
        revision: json['revision'] as int,
        importedAt: DateTime.parse(json['importedAt'] as String),
        immutable: json['immutable'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is BookAsset &&
      other.bookId == bookId &&
      other.localPath == localPath &&
      other.sha256 == sha256 &&
      other.revision == revision &&
      other.importedAt == importedAt &&
      other.immutable == immutable;

  @override
  int get hashCode => Object.hash(bookId, localPath, sha256, revision, importedAt, immutable);
}
