import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart' as data;
import '../domain/ids.dart';

/// Status of an outbox entry.
enum OutboxStatus { pending, inFlight, committed, failed, deadLetter }

/// A typed outbox entry representing a pending remote write.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.providerInstanceId,
    required this.bookId,
    required this.field,
    required this.payload,
    this.observedRemoteRevision,
    this.attempts = 0,
    required this.createdAt,
    this.status = OutboxStatus.pending,
  });

  final String id;
  final ProviderInstanceId providerInstanceId;
  final BookId bookId;
  final String field;
  final Map<String, dynamic> payload;
  final String? observedRemoteRevision;
  final int attempts;
  final DateTime createdAt;
  final OutboxStatus status;

  OutboxEntry copyWith({
    int? attempts,
    OutboxStatus? status,
    String? observedRemoteRevision,
  }) =>
      OutboxEntry(
        id: id,
        providerInstanceId: providerInstanceId,
        bookId: bookId,
        field: field,
        payload: payload,
        observedRemoteRevision: observedRemoteRevision ?? this.observedRemoteRevision,
        attempts: attempts ?? this.attempts,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}

/// Repository for outbox entries backed by Drift.
class OutboxRepository {
  OutboxRepository(this.db);

  final data.AppDatabase db;

  Future<void> enqueue(OutboxEntry entry) async {
    await db.into(db.outboxEntries).insert(
          data.OutboxEntriesCompanion.insert(
            id: entry.id,
            providerInstanceId: entry.providerInstanceId.value,
            bookId: entry.bookId.value,
            field: entry.field,
            payload: jsonEncode(entry.payload),
            observedRemoteRevision: Value(entry.observedRemoteRevision),
            attempts: Value(entry.attempts),
            createdAt: entry.createdAt,
            status: Value(entry.status.name),
          ),
        );
  }

  Future<List<OutboxEntry>> pending() async {
    final rows = await (db.select(db.outboxEntries)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toEntry).toList();
  }

  Future<void> markInFlight(String id) async {
    await (db.update(db.outboxEntries)..where((t) => t.id.equals(id))).write(
          const data.OutboxEntriesCompanion(status: Value('inFlight')),
        );
  }

  Future<void> markCommitted(String id) async {
    await (db.update(db.outboxEntries)..where((t) => t.id.equals(id))).write(
          const data.OutboxEntriesCompanion(status: Value('committed')),
        );
  }

  Future<void> markFailed(String id, {int? attempts}) async {
    final companion = attempts != null
        ? data.OutboxEntriesCompanion(
            status: const Value('failed'),
            attempts: Value(attempts),
          )
        : const data.OutboxEntriesCompanion(status: Value('failed'));
    await (db.update(db.outboxEntries)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> markDeadLetter(String id) async {
    await (db.update(db.outboxEntries)..where((t) => t.id.equals(id))).write(
          const data.OutboxEntriesCompanion(status: Value('deadLetter')),
        );
  }

  Future<void> remove(String id) async {
    await (db.delete(db.outboxEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<int> pendingCount() async {
    final rows = await (db.select(db.outboxEntries)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed')))
        .get();
    return rows.length;
  }

  Future<void> clearCommitted() async {
    await (db.delete(db.outboxEntries)..where((t) => t.status.equals('committed'))).go();
  }

  OutboxEntry _toEntry(data.OutboxEntry row) => OutboxEntry(
        id: row.id,
        providerInstanceId: ProviderInstanceId(row.providerInstanceId),
        bookId: BookId(row.bookId),
        field: row.field,
        payload: jsonDecode(row.payload) as Map<String, dynamic>,
        observedRemoteRevision: row.observedRemoteRevision,
        attempts: row.attempts,
        createdAt: row.createdAt,
        status: OutboxStatus.values.firstWhere(
          (s) => s.name == row.status,
          orElse: () => OutboxStatus.pending,
        ),
      );
}
