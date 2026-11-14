import 'ids.dart';
import 'locator.dart';

/// A bookmark anchored to a semantic locator.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.locator,
    this.label,
    this.createdAt,
  });

  final AnnotationId id;
  final BookId bookId;
  final ReadingLocator locator;
  final String? label;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'bookId': bookId.toJson(),
        'locator': locator.toJson(),
        'label': label,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: AnnotationId.fromJson(json['id'] as Map<String, dynamic>),
        bookId: BookId.fromJson(json['bookId'] as Map<String, dynamic>),
        locator: ReadingLocator.fromJson(json['locator'] as Map<String, dynamic>),
        label: json['label'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is Bookmark && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A highlight/note annotation (P1).
class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.locator,
    this.selectedText,
    this.note,
    this.color,
    this.createdAt,
  });

  final AnnotationId id;
  final BookId bookId;
  final ReadingLocator locator;
  final String? selectedText;
  final String? note;
  final String? color;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'bookId': bookId.toJson(),
        'locator': locator.toJson(),
        'selectedText': selectedText,
        'note': note,
        'color': color,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: AnnotationId.fromJson(json['id'] as Map<String, dynamic>),
        bookId: BookId.fromJson(json['bookId'] as Map<String, dynamic>),
        locator: ReadingLocator.fromJson(json['locator'] as Map<String, dynamic>),
        selectedText: json['selectedText'] as String?,
        note: json['note'] as String?,
        color: json['color'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is Annotation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
