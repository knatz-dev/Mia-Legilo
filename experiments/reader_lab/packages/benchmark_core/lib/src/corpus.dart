import 'dart:convert';

/// One generated EPUB in the shared corpus.
class CorpusBook {
  const CorpusBook({
    required this.id,
    required this.filename,
    required this.title,
    required this.source,
    required this.license,
    required this.sha256,
    required this.sizeBytes,
    required this.epubVersion,
    required this.spineItemCount,
    required this.notable,
  });

  final String id;
  final String filename;
  final String title;
  final String source;
  final String license;
  final String sha256;
  final int sizeBytes;
  final String epubVersion;
  final int spineItemCount;
  final String notable;

  factory CorpusBook.fromJson(Map<String, Object?> json) => CorpusBook(
        id: json['id']! as String,
        filename: json['filename']! as String,
        title: json['title']! as String,
        source: json['source']! as String,
        license: json['license']! as String,
        sha256: json['sha256']! as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        epubVersion: json['epubVersion']! as String,
        spineItemCount: (json['spineItemCount'] as num).toInt(),
        notable: json['notable']! as String,
      );
}

class CorpusManifest {
  const CorpusManifest({required this.books, required this.license});

  final List<CorpusBook> books;
  final String license;

  factory CorpusManifest.parse(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('Corpus manifest must be an object');
    }
    final rawBooks = decoded['books'];
    if (rawBooks is! List) {
      throw const FormatException('Corpus manifest is missing books');
    }
    return CorpusManifest(
      license: decoded['license'] as String? ?? '',
      books: [
        for (final entry in rawBooks)
          CorpusBook.fromJson((entry as Map).cast<String, Object?>()),
      ],
    );
  }
}
