import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/sync/outbox_repository.dart';
import 'package:mia_legilo/sync/conflict_store.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/domain/capability.dart';

void main() {
  test('OutboxStatus enum values', () {
    expect(OutboxStatus.values.length, 5);
    expect(OutboxStatus.pending.name, 'pending');
    expect(OutboxStatus.committed.name, 'committed');
  });

  test('CapabilityState isWritable', () {
    expect(CapabilityState.readWrite.isWritable, true);
    expect(CapabilityState.writeOnly.isWritable, true);
    expect(CapabilityState.readOnly.isWritable, false);
    expect(CapabilityState.unknown.isWritable, false);
  });

  test('BookConflict copyWith resolves', () {
    final c = BookConflict(
      id: 'c1',
      bookId: const BookId('b1'),
      field: 'readingStatus',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(c.resolved, false);
    final resolved = c.copyWith(resolved: true);
    expect(resolved.resolved, true);
    expect(resolved.id, 'c1');
  });
}
