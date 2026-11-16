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

    // Books: read if OPDS catalog reachable.
    try {
      await client.get('/opds');
      states[CapabilityResource.books] = CapabilityState.readOnly;
    } on CwngException catch (_) {
      states[CapabilityResource.books] = CapabilityState.unsupported;
    } catch (_) {
      states[CapabilityResource.books] = CapabilityState.unsupported;
    }

    // Downloads: OPDS acquisition links imply readable downloads.
    try {
      await client.get('/opds/books');
      states[CapabilityResource.downloads] = CapabilityState.readOnly;
    } catch (_) {
      states[CapabilityResource.downloads] = CapabilityState.unknown;
    }

    // CWNG write endpoints: verify app-password-based status writes.
    // POST /api/v1/books/{id}/read-status, /read, /archived accept Basic Auth.
    // We verify the endpoint exists (not 404) without writing test data.
    if (auth.isBasic) {
      // Check if the CWNG write API is available by probing a non-existent book.
      // A 404 or 405 means the endpoint exists but the book doesn't (expected).
      // A 401/403 means auth is insufficient.
      try {
        await client.post('/api/v1/books/probe/read-status',
            data: <String, dynamic>{'status': 'unread'});
        // If we get here, the endpoint accepted the request (unlikely for probe).
        states[CapabilityResource.status] = CapabilityState.readWrite;
      } on CwngException catch (e) {
        if (e.statusCode == 404 || e.statusCode == 405 || e.statusCode == 400) {
          // Endpoint exists but book not found / method not allowed / bad request.
          // This means the CWNG write API is available.
          states[CapabilityResource.status] = CapabilityState.readWrite;
        } else if (e.statusCode == 401 || e.statusCode == 403) {
          states[CapabilityResource.status] = CapabilityState.readOnly;
        } else {
          states[CapabilityResource.status] = CapabilityState.unknown;
        }
      } catch (_) {
        states[CapabilityResource.status] = CapabilityState.unknown;
      }

      // Mark read (mark a book as read) uses the same auth.
      if (states[CapabilityResource.status] == CapabilityState.readWrite) {
        states[CapabilityResource.progress] = CapabilityState.readWrite;
      }
    }

    // Shelves/bookmarks/annotations: OPDS doesn't support writes.
    // CWNG doesn't have shelf sync via OPDS. Keep as unknown.
    return CapabilityMatrix(states);
  }
}
