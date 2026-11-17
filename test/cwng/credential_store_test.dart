import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/data/app_database.dart' as data;
import 'package:mia_legilo/domain/book.dart';
import 'package:mia_legilo/domain/capability.dart';
import 'package:mia_legilo/domain/ids.dart';
import 'package:mia_legilo/domain/provider_contract.dart';
import 'package:mia_legilo/domain/status.dart';
import 'package:mia_legilo/features/settings/settings_model.dart';
import 'package:mia_legilo/integrations/cwng/credential_store.dart';
import 'package:mia_legilo/integrations/cwng/token_store.dart';
import 'package:mia_legilo/sync/conflict_store.dart';
import 'package:mia_legilo/sync/outbox_repository.dart';
import 'package:mia_legilo/sync/sync_service.dart';

class _MemoryTokenStore implements TokenStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

void main() {
  group('CwngCredentialStore', () {
    test('stores a profile-keyed Basic token, not the raw password', () async {
      final _MemoryTokenStore backing = _MemoryTokenStore();
      final CwngCredentialStore store = CwngCredentialStore(store: backing);

      await store.write('cwng-host-a', 'alice', 's3cret-app-password');

      final String? token = await store.read('cwng-host-a');
      expect(token, isNotNull);
      // The secret is only recoverable as user:password after decoding.
      expect(utf8.decode(base64Decode(token!)), 'alice:s3cret-app-password');
      // The raw password never lands in the backing store.
      expect(backing._values.values, isNot(contains('s3cret-app-password')));
      expect(backing._values.keys, contains('cwng.basic.cwng-host-a'));
    });

    test('keys do not collide across profiles', () async {
      final _MemoryTokenStore backing = _MemoryTokenStore();
      final CwngCredentialStore store = CwngCredentialStore(store: backing);

      await store.write('profile-a', 'alice', 'one');
      await store.write('profile-b', 'bob', 'two');

      expect(await store.read('profile-a'), isNot(await store.read('profile-b')));
    });

    test('delete removes only that profile', () async {
      final _MemoryTokenStore backing = _MemoryTokenStore();
      final CwngCredentialStore store = CwngCredentialStore(store: backing);

      await store.write('profile-a', 'alice', 'one');
      await store.write('profile-b', 'bob', 'two');
      await store.delete('profile-a');

      expect(await store.read('profile-a'), isNull);
      expect(await store.read('profile-b'), isNotNull);
    });
  });

  group('ConnectionProfile', () {
    test('JSON carries the username but never a password', () {
      const ConnectionProfile profile = ConnectionProfile(
        id: 'cwng-host-a',
        serverUrl: 'https://library.example.org',
        username: 'alice',
        label: 'Home',
      );
      final String raw = jsonEncode(profile.toJson());
      expect(raw, contains('alice'));
      expect(raw, contains('https://library.example.org'));
      expect(raw.toLowerCase(), isNot(contains('password')));
    });
  });

  group('status write gating', () {
    late Directory dir;
    late File file;
    late data.AppDatabase db;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mia_status_gate_');
      file = File('${dir.path}/test.sqlite');
      db = data.AppDatabase(NativeDatabase(file));
    });

    tearDown(() async {
      await db.close();
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Already removed.
      }
    });

    SyncService buildSync(CapabilityMatrix caps) {
      final _FakeProvider provider = _FakeProvider(caps);
      return SyncService(
        outbox: OutboxRepository(db),
        conflicts: ConflictStore(db),
        provider: provider,
        db: db,
      );
    }

    test('enqueues when status is readWrite, regardless of books', () async {
      final SyncService sync = buildSync(
        const CapabilityMatrix(<CapabilityResource, CapabilityState>{
          CapabilityResource.books: CapabilityState.readOnly,
          CapabilityResource.status: CapabilityState.readWrite,
        }),
      );
      await sync.enqueueStatusChange(
        bookId: const BookId('book-1'),
        status: ReadingStatus.reading,
        providerInstanceId: const ProviderInstanceId('cwng'),
        remoteBookId: 'remote-1',
      );
      expect(await OutboxRepository(db).pendingCount(), 1);
    });

    test('does not enqueue when only books is writable', () async {
      final SyncService sync = buildSync(
        const CapabilityMatrix(<CapabilityResource, CapabilityState>{
          CapabilityResource.books: CapabilityState.readWrite,
          CapabilityResource.status: CapabilityState.unknown,
        }),
      );
      await sync.enqueueStatusChange(
        bookId: const BookId('book-1'),
        status: ReadingStatus.reading,
        providerInstanceId: const ProviderInstanceId('cwng'),
      );
      expect(await OutboxRepository(db).pendingCount(), 0);
    });
  });
}

class _FakeProvider implements LibraryProvider {
  _FakeProvider(this._caps);

  final CapabilityMatrix _caps;

  @override
  CapabilityMatrix get capabilities => _caps;

  @override
  ProviderInstanceId get instanceId => const ProviderInstanceId('cwng');

  @override
  Future<List<Book>> browseBooks({int page = 0, int pageSize = 50}) async =>
      <Book>[];

  @override
  Future<Book?> fetchBook(RemoteIdentity remote) async => null;

  @override
  Future<String> downloadBook(RemoteIdentity remote, String p) async => p;

  @override
  Future<CapabilityMatrix> refreshCapabilities() async => _caps;
}
