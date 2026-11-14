import 'ids.dart';

/// A shelf (manual or system status shelf).
class Shelf {
  const Shelf({
    required this.id,
    required this.name,
    this.isSystem = false,
    this.description,
    this.createdAt,
  });

  final ShelfId id;
  final String name;
  final bool isSystem;
  final String? description;
  final DateTime? createdAt;

  Shelf copyWith({String? name, String? description}) => Shelf(
        id: id,
        name: name ?? this.name,
        isSystem: isSystem,
        description: description ?? this.description,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'name': name,
        'isSystem': isSystem,
        'description': description,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Shelf.fromJson(Map<String, dynamic> json) => Shelf(
        id: ShelfId.fromJson(json['id'] as Map<String, dynamic>),
        name: json['name'] as String,
        isSystem: json['isSystem'] as bool? ?? false,
        description: json['description'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) => other is Shelf && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
