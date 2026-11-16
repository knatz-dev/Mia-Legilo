/// Inventory of CWNG endpoints. All entries default to `verified = false`
/// until confirmed against a real deployment (INT-003).
class CwngEndpoint {
  const CwngEndpoint({
    required this.operation,
    required this.method,
    required this.pathTemplate,
    this.verified = false,
    this.notes,
  });

  final String operation;
  final String method;
  final String pathTemplate;
  final bool verified;
  final String? notes;
}

class CwngEndpointInventory {
  const CwngEndpointInventory(this.endpoints);

  final List<CwngEndpoint> endpoints;

  CwngEndpoint? find(String operation) {
    for (final e in endpoints) {
      if (e.operation == operation) return e;
    }
    return null;
  }
}

/// Default inventory with best-effort paths. None are verified.
const defaultCwngInventory = CwngEndpointInventory(<CwngEndpoint>[
  CwngEndpoint(operation: 'auth.basic', method: 'GET', pathTemplate: '/opds', verified: true, notes: 'HTTP Basic Auth; verified against library.knatz.dev'),
  CwngEndpoint(operation: 'opds.catalog', method: 'GET', pathTemplate: '/opds', verified: true),
  CwngEndpoint(operation: 'opds.books', method: 'GET', pathTemplate: '/opds/books', verified: true),
  CwngEndpoint(operation: 'cwng.readStatus', method: 'POST', pathTemplate: '/api/v1/books/{id}/read-status', verified: true, notes: 'Set reading status; accepts Basic Auth with app password'),
  CwngEndpoint(operation: 'cwng.markRead', method: 'POST', pathTemplate: '/api/v1/books/{id}/read', verified: true, notes: 'Mark a book as read; accepts Basic Auth with app password'),
  CwngEndpoint(operation: 'cwng.archive', method: 'POST', pathTemplate: '/api/v1/books/{id}/archived', verified: true, notes: 'Archive a book; accepts Basic Auth with app password'),
  CwngEndpoint(operation: 'auth.login', method: 'POST', pathTemplate: '/api/auth/login', verified: false, notes: 'Not used by CWNG; OPDS basic auth instead'),
  CwngEndpoint(operation: 'auth.refresh', method: 'POST', pathTemplate: '/api/auth/refresh', verified: false),
  CwngEndpoint(operation: 'books.list', method: 'GET', pathTemplate: '/api/books', verified: false, notes: 'Returns login page; not a JSON API'),
  CwngEndpoint(operation: 'books.get', method: 'GET', pathTemplate: '/api/books/{id}', verified: false),
  CwngEndpoint(operation: 'books.download', method: 'GET', pathTemplate: '/opds/.../acquisition', verified: false, notes: 'href from OPDS entry link'),
]);
