import '../../domain/domain.dart';
import 'cwng_client.dart';
import 'cwng_auth.dart';
import 'cwng_errors.dart';

/// Probes a CWNG deployment and produces a [CapabilityMatrix].
/// All writes remain `unknown` until explicitly verified; probing never
/// assumes write access (INT-005).
class CwngCapabilityProbe {
  CwngCapabilityProbe({required this.client});

  final CwngClient client;

  Future<CapabilityMatrix> probe(CwngAuthState auth) async {
    client.attachAuth(auth);
    final states = <CapabilityResource, CapabilityState>{
      for (final r in CapabilityResource.values) r: CapabilityState.unknown,
    };

    // Books: read if list endpoint reachable.
    try {
      await client.get('/api/books');
      states[CapabilityResource.books] = CapabilityState.readOnly;
    } on CwngException catch (_) {
      states[CapabilityResource.books] = CapabilityState.unsupported;
    } catch (_) {
      states[CapabilityResource.books] = CapabilityState.unsupported;
    }

    // Downloads: read if a download endpoint responds (HEAD/GET).
    try {
      await client.get('/api/books/0/download');
      states[CapabilityResource.downloads] = CapabilityState.readOnly;
    } catch (_) {
      states[CapabilityResource.downloads] = CapabilityState.unknown;
    }

    // Status/progress/shelves/bookmarks/annotations: unverified by default.
    // They are only upgraded after explicit verification (INT-005).
    client.detachAuth();
    return CapabilityMatrix(states);
  }
}
