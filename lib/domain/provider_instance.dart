import 'ids.dart';

/// A network endpoint (scheme+host+port). TLS enforcement is a property.
class Endpoint {
  const Endpoint({
    required this.id,
    required this.url,
    this.tlsEnforced = true,
    this.allowRedirects = false,
  });

  final EndpointId id;
  final String url;
  final bool tlsEnforced;
  final bool allowRedirects;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'url': url,
        'tlsEnforced': tlsEnforced,
        'allowRedirects': allowRedirects,
      };

  factory Endpoint.fromJson(Map<String, dynamic> json) => Endpoint(
        id: EndpointId.fromJson(json['id'] as Map<String, dynamic>),
        url: json['url'] as String,
        tlsEnforced: json['tlsEnforced'] as bool? ?? true,
        allowRedirects: json['allowRedirects'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is Endpoint && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Server identity within an endpoint.
class Server {
  const Server({required this.id, required this.endpointId, this.displayName});

  final ServerId id;
  final EndpointId endpointId;
  final String? displayName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'endpointId': endpointId.toJson(),
        'displayName': displayName,
      };

  factory Server.fromJson(Map<String, dynamic> json) => Server(
        id: ServerId.fromJson(json['id'] as Map<String, dynamic>),
        endpointId: EndpointId.fromJson(json['endpointId'] as Map<String, dynamic>),
        displayName: json['displayName'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Server && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Library identity within a server.
class Library {
  const Library({required this.id, required this.serverId, this.displayName});

  final LibraryId id;
  final ServerId serverId;
  final String? displayName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'serverId': serverId.toJson(),
        'displayName': displayName,
      };

  factory Library.fromJson(Map<String, dynamic> json) => Library(
        id: LibraryId.fromJson(json['id'] as Map<String, dynamic>),
        serverId: ServerId.fromJson(json['serverId'] as Map<String, dynamic>),
        displayName: json['displayName'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Library && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Account identity within a library.
class Account {
  const Account({required this.id, required this.libraryId, this.displayName});

  final AccountId id;
  final LibraryId libraryId;
  final String? displayName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'libraryId': libraryId.toJson(),
        'displayName': displayName,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: AccountId.fromJson(json['id'] as Map<String, dynamic>),
        libraryId: LibraryId.fromJson(json['libraryId'] as Map<String, dynamic>),
        displayName: json['displayName'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Account && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A configured provider instance binding endpoint/server/library/account.
/// Distinct identities prevent cross-account merging.
class ProviderInstance {
  const ProviderInstance({
    required this.id,
    required this.endpointId,
    required this.serverId,
    required this.libraryId,
    required this.accountId,
  });

  final ProviderInstanceId id;
  final EndpointId endpointId;
  final ServerId serverId;
  final LibraryId libraryId;
  final AccountId accountId;

  /// Whether two bindings refer to the same account (verified rebind).
  bool sameAccountAs(ProviderInstance other) =>
      endpointId == other.endpointId &&
      serverId == other.serverId &&
      libraryId == other.libraryId &&
      accountId == other.accountId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id.toJson(),
        'endpointId': endpointId.toJson(),
        'serverId': serverId.toJson(),
        'libraryId': libraryId.toJson(),
        'accountId': accountId.toJson(),
      };

  factory ProviderInstance.fromJson(Map<String, dynamic> json) => ProviderInstance(
        id: ProviderInstanceId.fromJson(json['id'] as Map<String, dynamic>),
        endpointId: EndpointId.fromJson(json['endpointId'] as Map<String, dynamic>),
        serverId: ServerId.fromJson(json['serverId'] as Map<String, dynamic>),
        libraryId: LibraryId.fromJson(json['libraryId'] as Map<String, dynamic>),
        accountId: AccountId.fromJson(json['accountId'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) => other is ProviderInstance && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A verified binding between a provider instance and an account.
/// Account-switch isolation: a rebind is valid only if verified.
class VerifiedBinding {
  const VerifiedBinding({
    required this.providerInstanceId,
    required this.accountId,
    required this.verifiedAt,
  });

  final ProviderInstanceId providerInstanceId;
  final AccountId accountId;
  final DateTime verifiedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'providerInstanceId': providerInstanceId.toJson(),
        'accountId': accountId.toJson(),
        'verifiedAt': verifiedAt.toIso8601String(),
      };

  factory VerifiedBinding.fromJson(Map<String, dynamic> json) => VerifiedBinding(
        providerInstanceId: ProviderInstanceId.fromJson(
            json['providerInstanceId'] as Map<String, dynamic>),
        accountId: AccountId.fromJson(json['accountId'] as Map<String, dynamic>),
        verifiedAt: DateTime.parse(json['verifiedAt'] as String),
      );
}
