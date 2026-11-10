import 'reading_location.dart';

/// A locally stored one-tap bookmark.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.engineId,
    required this.location,
    required this.createdAt,
    this.chapterLabel,
    this.excerpt,
  });

  final String id;
  final String bookId;
  final String engineId;
  final ReadingLocation location;
  final DateTime createdAt;
  final String? chapterLabel;
  final String? excerpt;

  Map<String, Object?> toJson() => {
        'id': id,
        'bookId': bookId,
        'engineId': engineId,
        'location': location.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'chapterLabel': chapterLabel,
        'excerpt': excerpt,
      };

  factory Bookmark.fromJson(Map<String, Object?> json) => Bookmark(
        id: json['id']! as String,
        bookId: json['bookId']! as String,
        engineId: json['engineId']! as String,
        location: ReadingLocation.fromJson(
          (json['location']! as Map).cast<String, Object?>(),
        ),
        createdAt: DateTime.parse(json['createdAt']! as String),
        chapterLabel: json['chapterLabel'] as String?,
        excerpt: json['excerpt'] as String?,
      );
}
