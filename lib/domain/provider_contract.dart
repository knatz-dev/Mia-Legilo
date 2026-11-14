import 'ids.dart';
import 'book.dart';
import 'capability.dart';

/// Provider-neutral library provider contract.
///
/// All remote operations are capability-gated: callers must check the
/// [CapabilityMatrix] before invoking writes.
abstract class LibraryProvider {
  ProviderInstanceId get instanceId;

  CapabilityMatrix get capabilities;

  /// Paged metadata browsing.
  Future<List<Book>> browseBooks({int page = 0, int pageSize = 50});

  /// Download an EPUB to a local path. Returns the local path.
  Future<String> downloadBook(RemoteIdentity remote, String destinationPath);

  /// Fetch a single remote book's metadata.
  Future<Book?> fetchBook(RemoteIdentity remote);

  /// Negotiate/refresh capabilities.
  Future<CapabilityMatrix> refreshCapabilities();
}
