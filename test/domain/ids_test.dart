import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/domain/domain.dart';

void main() {
  group('BookId', () {
    test('equality by value', () {
      expect(const BookId('a'), equals(const BookId('a')));
      expect(const BookId('a'), isNot(equals(const BookId('b'))));
    });
    test('json round trip', () {
      const id = BookId('abc');
      expect(BookId.fromJson(id.toJson()), equals(id));
    });
  });

  group('RemoteIdentity', () {
    test('json round trip', () {
      const ri = RemoteIdentity(
        providerInstanceId: ProviderInstanceId('p1'),
        remoteBookId: RemoteBookId('r1'),
      );
      expect(RemoteIdentity.fromJson(ri.toJson()), equals(ri));
    });
  });

  group('CapabilityMatrix', () {
    test('defaults unknown', () {
      final m = CapabilityMatrix.allUnknown();
      for (final r in CapabilityResource.values) {
        expect(m.stateOf(r), CapabilityState.unknown);
      }
    });
    test('copyWith updates one resource', () {
      final m = CapabilityMatrix.allUnknown()
          .copyWith(CapabilityResource.books, CapabilityState.readWrite);
      expect(m.stateOf(CapabilityResource.books), CapabilityState.readWrite);
      expect(m.stateOf(CapabilityResource.downloads), CapabilityState.unknown);
    });
    test('json round trip', () {
      final m = CapabilityMatrix.allUnknown()
          .copyWith(CapabilityResource.status, CapabilityState.readOnly);
      expect(CapabilityMatrix.fromJson(m.toJson()), equals(m));
    });
  });

  group('ProviderInstance', () {
    test('sameAccountAs checks all identities', () {
      const a = ProviderInstance(
        id: ProviderInstanceId('i1'),
        endpointId: EndpointId('e1'),
        serverId: ServerId('s1'),
        libraryId: LibraryId('l1'),
        accountId: AccountId('a1'),
      );
      const b = ProviderInstance(
        id: ProviderInstanceId('i2'),
        endpointId: EndpointId('e1'),
        serverId: ServerId('s1'),
        libraryId: LibraryId('l1'),
        accountId: AccountId('a1'),
      );
      expect(a.sameAccountAs(b), isTrue);
      const c = ProviderInstance(
        id: ProviderInstanceId('i3'),
        endpointId: EndpointId('e1'),
        serverId: ServerId('s1'),
        libraryId: LibraryId('l1'),
        accountId: AccountId('a2'),
      );
      expect(a.sameAccountAs(c), isFalse);
    });
  });
}
