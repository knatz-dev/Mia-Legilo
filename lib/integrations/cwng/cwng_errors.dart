/// Error taxonomy for CWNG operations.
enum CwngErrorKind {
  network,
  tls,
  authentication,
  authorization,
  notFound,
  server,
  unknown,
}

class CwngException implements Exception {
  const CwngException(
    this.kind,
    this.message, {
    this.statusCode,
    this.cause,
  });

  final CwngErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'CwngException($kind, $statusCode): $message';
}
