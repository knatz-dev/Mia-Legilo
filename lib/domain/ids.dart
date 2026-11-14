library;

/// Stable, typed identifiers for Mia Legilo's domain and provider model.
///
/// All identifiers are value objects: equality is by value, they are immutable,
/// and they serialize to/from JSON for persistence and IPC.

class _Id {
  const _Id(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is _Id && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$runtimeType($value)';

  Map<String, dynamic> toJson() => <String, dynamic>{'value': value};
}

/// Local book identity. Never derived from title/author similarity.
class BookId extends _Id {
  const BookId(super.value);
  factory BookId.fromJson(Map<String, dynamic> json) =>
      BookId(json['value'] as String);
}

/// Identifies a configured CWNG (or other) provider instance.
class ProviderInstanceId extends _Id {
  const ProviderInstanceId(super.value);
  factory ProviderInstanceId.fromJson(Map<String, dynamic> json) =>
      ProviderInstanceId(json['value'] as String);
}

/// Remote book identity within a provider instance.
class RemoteBookId extends _Id {
  const RemoteBookId(super.value);
  factory RemoteBookId.fromJson(Map<String, dynamic> json) =>
      RemoteBookId(json['value'] as String);
}

/// Network endpoint identity (scheme+host+port normalized).
class EndpointId extends _Id {
  const EndpointId(super.value);
  factory EndpointId.fromJson(Map<String, dynamic> json) =>
      EndpointId(json['value'] as String);
}

/// Server identity (distinct from endpoint/account).
class ServerId extends _Id {
  const ServerId(super.value);
  factory ServerId.fromJson(Map<String, dynamic> json) =>
      ServerId(json['value'] as String);
}

/// Library identity within a server.
class LibraryId extends _Id {
  const LibraryId(super.value);
  factory LibraryId.fromJson(Map<String, dynamic> json) =>
      LibraryId(json['value'] as String);
}

/// Account identity within a server/library.
class AccountId extends _Id {
  const AccountId(super.value);
  factory AccountId.fromJson(Map<String, dynamic> json) =>
      AccountId(json['value'] as String);
}

/// Shelf identity.
class ShelfId extends _Id {
  const ShelfId(super.value);
  factory ShelfId.fromJson(Map<String, dynamic> json) =>
      ShelfId(json['value'] as String);
}

/// Annotation/bookmark identity.
class AnnotationId extends _Id {
  const AnnotationId(super.value);
  factory AnnotationId.fromJson(Map<String, dynamic> json) =>
      AnnotationId(json['value'] as String);
}

/// Composite remote identity: (providerInstanceId, remoteBookId).
class RemoteIdentity {
  const RemoteIdentity({
    required this.providerInstanceId,
    required this.remoteBookId,
  });

  final ProviderInstanceId providerInstanceId;
  final RemoteBookId remoteBookId;

  @override
  bool operator ==(Object other) =>
      other is RemoteIdentity &&
      other.providerInstanceId == providerInstanceId &&
      other.remoteBookId == remoteBookId;

  @override
  int get hashCode => Object.hash(providerInstanceId, remoteBookId);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'providerInstanceId': providerInstanceId.toJson(),
        'remoteBookId': remoteBookId.toJson(),
      };

  factory RemoteIdentity.fromJson(Map<String, dynamic> json) => RemoteIdentity(
        providerInstanceId: ProviderInstanceId.fromJson(
            json['providerInstanceId'] as Map<String, dynamic>),
        remoteBookId: RemoteBookId.fromJson(
            json['remoteBookId'] as Map<String, dynamic>),
      );
}
