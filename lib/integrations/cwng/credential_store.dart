import 'dart:convert';

import 'secure_token_store.dart';
import 'token_store.dart';

/// Basic-auth secret for one connection profile, keyed by profile id so a
/// second server does not overwrite the first.
///
/// The password never enters Drift or [ConnectionProfile.toJson] — the
/// non-secret profile carries the username and URL, and this store holds only
/// the derived `user:password` Basic token in platform secure storage.
class CwngCredentialStore {
  CwngCredentialStore({TokenStore? store}) : _store = store ?? SecureTokenStore();

  final TokenStore _store;

  String _key(String profileId) => 'cwng.basic.$profileId';

  Future<void> write(String profileId, String username, String password) {
    final String token = base64Encode(utf8.encode('$username:$password'));
    return _store.write(_key(profileId), token);
  }

  Future<String?> read(String profileId) => _store.read(_key(profileId));

  Future<void> delete(String profileId) => _store.delete(_key(profileId));
}
