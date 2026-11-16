import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart' as data;
import '../domain/ids.dart';

/// A conflict between local and remote values for a book field.
class BookConflict {
  const BookConflict({
    required this.id,
    required this.bookId,
    required this.field,
    this.localValue,
    this.remoteValue,
    required this.createdAt,
    this.resolved = false,
  });

  final String id;
  final BookId bookId;
  final String field;
  final Map<String, dynamic>? localValue;
  final Map<String, dynamic>? remoteValue;
  final DateTime createdAt;
  final bool resolved;

  BookConflict copyWith({bool? resolved}) => BookConflict(
        id: id,
        bookId: bookId,
        field: field,
        localValue: localValue,
        remoteValue: remoteValue,
        createdAt: createdAt,
        resolved: resolved ?? this.resolved,
      );
}

/// Repository for conflicts backed by Drift.
class ConflictStore {
  ConflictStore(this.db);

  final data.AppDatabase db;

  Future<void> add(BookConflict conflict) async {
    await db.into(db.conflicts).insert(
          data.ConflictsCompanion.insert(
            id: conflict.id,
            bookId: conflict.bookId.value,
            field: conflict.field,
            localValue: Value(conflict.localValue == null ? null : jsonEncode(conflict.localValue)),
            remoteValue: Value(conflict.remoteValue == null ? null : jsonEncode(conflict.remoteValue)),
            createdAt: conflict.createdAt,
            resolved: Value(conflict.resolved),
          ),
        );
  }

  Future<List<BookConflict>> unresolvedFor(BookId bookId) async {
    final rows = await (db.select(db.conflicts)
          ..where((t) => t.bookId.equals(bookId.value))
          ..where((t) => t.resolved.equals(false)))
        .get();
    return rows.map(_toConflict).toList();
  }

  Future<List<BookConflict>> allUnresolved() async {
    final rows = await (db.select(db.conflicts)
          ..where((t) => t.resolved.equals(false)))
        .get();
    return rows.map(_toConflict).toList();
  }

  Future<void> resolve(String id) async {
    await (db.update(db.conflicts)..where((t) => t.id.equals(id))).write(
          const data.ConflictsCompanion(resolved: Value(true)),
        );
  }

  Future<bool> hasUnresolved(BookId bookId, String field) async {
    final rows = await (db.select(db.conflicts)
          ..where((t) => t.bookId.equals(bookId.value))
          ..where((t) => t.field.equals(field))
          ..where((t) => t.resolved.equals(false)))
        .get();
    return rows.isNotEmpty;
  }

  BookConflict _toConflict(data.Conflict row) => BookConflict(
        id: row.id,
        bookId: BookId(row.bookId),
        field: row.field,
        localValue: row.localValue == null
            ? null
            : jsonDecode(row.localValue!) as Map<String, dynamic>,
        remoteValue: row.remoteValue == null
            ? null
            : jsonDecode(row.remoteValue!) as Map<String, dynamic>,
        createdAt: row.createdAt,
        resolved: row.resolved,
      );
}
