import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/data/app_database.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/sync/outbox_repository.dart' as sync;

void main() {
  group('Restart recovery', () {
    test('in-flight entries are recovered to failed on reopen', () async {
      final dir = await Directory.systemTemp.createTemp('mia_restart_');
      final file = File('${dir.path}/test.sqlite');
      try {
        // Create DB and enqueue an entry, mark it in-flight.
        AppDatabase db = AppDatabase(NativeDatabase(file));
        final outbox = sync.OutboxRepository(db);
        final entry = sync.OutboxEntry(
          id: 'restart-test-1',
          providerInstanceId: const ProviderInstanceId('cwng'),
          bookId: const BookId('book-1'),
          field: 'readingStatus',
          payload: <String, dynamic>{'status': 'reading'},
          createdAt: DateTime.utc(2026, 1, 1),
        );
        await outbox.enqueue(entry);
        await outbox.markInFlight(entry.id);

        // Verify it's in-flight.
        final pendingBefore = await outbox.pending();
        expect(pendingBefore, isEmpty); // in-flight is not pending

        await db.close();

        // Reopen DB and run recovery.
        db = AppDatabase(NativeDatabase(file));
        final outbox2 = sync.OutboxRepository(db);
        // Simulate recoverOnStartup: mark in-flight → failed.
        final allEntries = await db.select(db.outboxEntries).get();
        for (final row in allEntries) {
          if (row.status == 'inFlight') {
            await outbox2.markFailed(row.id, attempts: row.attempts);
          }
        }

        // After recovery, the entry should be in pending (failed → retryable).
        final pendingAfter = await outbox2.pending();
        expect(pendingAfter, hasLength(1));
        expect(pendingAfter.first.id, 'restart-test-1');
        expect(pendingAfter.first.status, sync.OutboxStatus.failed);

        await db.close();
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await dir.exists()) {
          try {
            await dir.delete(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('committed entries are cleaned up on sync', () async {
      final dir = await Directory.systemTemp.createTemp('mia_cleanup_');
      final file = File('${dir.path}/test.sqlite');
      try {
        AppDatabase db = AppDatabase(NativeDatabase(file));
        final outbox = sync.OutboxRepository(db);
        final entry = sync.OutboxEntry(
          id: 'cleanup-test-1',
          providerInstanceId: const ProviderInstanceId('cwng'),
          bookId: const BookId('book-1'),
          field: 'readingStatus',
          payload: <String, dynamic>{'status': 'completed'},
          createdAt: DateTime.utc(2026, 1, 1),
        );
        await outbox.enqueue(entry);
        await outbox.markCommitted(entry.id);

        // Pending should be empty.
        final pending = await outbox.pending();
        expect(pending, isEmpty);

        // Clear committed.
        await outbox.clearCommitted();
        final all = await db.select(db.outboxEntries).get();
        expect(all, isEmpty);

        await db.close();
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await dir.exists()) {
          try {
            await dir.delete(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('dead-letter after max attempts', () async {
      final dir = await Directory.systemTemp.createTemp('mia_deadletter_');
      final file = File('${dir.path}/test.sqlite');
      try {
        AppDatabase db = AppDatabase(NativeDatabase(file));
        final outbox = sync.OutboxRepository(db);
        final entry = sync.OutboxEntry(
          id: 'dead-test-1',
          providerInstanceId: const ProviderInstanceId('cwng'),
          bookId: const BookId('book-1'),
          field: 'readingStatus',
          payload: <String, dynamic>{'status': 'reading'},
          createdAt: DateTime.utc(2026, 1, 1),
          attempts: 5,
        );
        await outbox.enqueue(entry);
        await outbox.markFailed(entry.id, attempts: 5);
        await outbox.markDeadLetter(entry.id);

        final pending = await outbox.pending();
        expect(pending, isEmpty); // dead-letter is not pending

        final all = await db.select(db.outboxEntries).get();
        expect(all.first.status, 'deadLetter');

        await db.close();
      } finally {
        await Future.delayed(const Duration(milliseconds: 200));
        if (await dir.exists()) {
          try {
            await dir.delete(recursive: true);
          } catch (_) {}
        }
      }
    });
  });
}
