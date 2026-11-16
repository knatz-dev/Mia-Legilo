import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/sync/outbox_repository.dart';
import 'package:mia_legilo/sync/conflict_store.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/domain/capability.dart';
import 'package:mia_legilo/sync/sync_service.dart';

void main() {
  group('OutboxEntry', () {
    test('copyWith updates status and attempts', () {
      final entry = OutboxEntry(
        id: 'e1',
        providerInstanceId: const ProviderInstanceId('p1'),
        bookId: const BookId('b1'),
        field: 'readingStatus',
        payload: <String, dynamic>{'status': 'reading'},
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(entry.status, OutboxStatus.pending);
      expect(entry.attempts, 0);

      final updated = entry.copyWith(status: OutboxStatus.inFlight, attempts: 1);
      expect(updated.status, OutboxStatus.inFlight);
      expect(updated.attempts, 1);
      expect(updated.id, 'e1');
    });

    test('copyWith updates observedRemoteRevision', () {
      final entry = OutboxEntry(
        id: 'e2',
        providerInstanceId: const ProviderInstanceId('p1'),
        bookId: const BookId('b1'),
        field: 'readingStatus',
        payload: <String, dynamic>{'status': 'completed'},
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final updated = entry.copyWith(observedRemoteRevision: 'rev-123');
      expect(updated.observedRemoteRevision, 'rev-123');
    });
  });

  group('SyncResult', () {
    test('hasErrors is true when failed > 0', () {
      const r = SyncResult(failed: 1);
      expect(r.hasErrors, true);
    });

    test('hasErrors is true when error is set', () {
      const r = SyncResult(error: 'network');
      expect(r.hasErrors, true);
    });

    test('hasErrors is false when no failures', () {
      const r = SyncResult(processed: 5, committed: 5);
      expect(r.hasErrors, false);
    });
  });

  group('Capability gating', () {
    test('readOnly capability blocks enqueue', () {
      final caps = CapabilityMatrix(<CapabilityResource, CapabilityState>{
        CapabilityResource.books: CapabilityState.readOnly,
      });
      expect(caps.stateOf(CapabilityResource.books).isWritable, false);
    });

    test('readWrite capability allows enqueue', () {
      final caps = CapabilityMatrix(<CapabilityResource, CapabilityState>{
        CapabilityResource.books: CapabilityState.readWrite,
      });
      expect(caps.stateOf(CapabilityResource.books).isWritable, true);
    });

    test('unknown capability blocks enqueue', () {
      final caps = CapabilityMatrix(<CapabilityResource, CapabilityState>{
        CapabilityResource.books: CapabilityState.unknown,
      });
      expect(caps.stateOf(CapabilityResource.books).isWritable, false);
    });
  });

  group('ConflictStore', () {
    test('BookConflict fields', () {
      final c = BookConflict(
        id: 'c1',
        bookId: const BookId('b1'),
        field: 'readingStatus',
        localValue: <String, dynamic>{'status': 'reading'},
        remoteValue: <String, dynamic>{'status': 'completed'},
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(c.resolved, false);
      expect(c.localValue!['status'], 'reading');
      expect(c.remoteValue!['status'], 'completed');
    });
  });
}
