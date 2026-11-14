import 'package:dio/dio.dart';

import 'token_store.dart';
import 'cwng_errors.dart';

/// Credentials used for authentication.
class CwngCredentials {
  const CwngCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

/// Authenticated session state.
class CwngAuthState {
  const CwngAuthState({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isExpired {
    final e = expiresAt;
    if (e == null) return false;
    return DateTime.now().isAfter(e);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory CwngAuthState.fromJson(Map<String, dynamic> json) => CwngAuthState(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
      );
}

/// Authenticator handling login, refresh, restore, logout.
class CwngAuthenticator {
  CwngAuthenticator({
    required this.dio,
    required this.tokenStore,
    required this.baseUrl,
    this.loginPath = '/api/auth/login',
    this.refreshPath = '/api/auth/refresh',
  });

  final Dio dio;
  final TokenStore tokenStore;
  final String baseUrl;
  final String loginPath;
  final String refreshPath;

  static const _tokenKey = 'cwng_access_token';
  static const _refreshKey = 'cwng_refresh_token';
  static const _expiryKey = 'cwng_token_expiry';

  Future<CwngAuthState> login(CwngCredentials credentials) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        loginPath,
        data: <String, dynamic>{
          'username': credentials.username,
          'password': credentials.password,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      final state = CwngAuthState(
        accessToken: data['access_token'] as String? ?? data['token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String?,
        expiresAt: _parseExpiry(data),
      );
      await _persist(state);
      return state;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CwngAuthState?> restore() async {
    final token = await tokenStore.read(_tokenKey);
    if (token == null || token.isEmpty) return null;
    final refresh = await tokenStore.read(_refreshKey);
    final expiryRaw = await tokenStore.read(_expiryKey);
    final expiry = expiryRaw == null ? null : DateTime.tryParse(expiryRaw);
    return CwngAuthState(accessToken: token, refreshToken: refresh, expiresAt: expiry);
  }

  Future<CwngAuthState> refresh(CwngAuthState current) async {
    if (current.refreshToken == null) {
      throw const CwngException(CwngErrorKind.authentication, 'No refresh token');
    }
    try {
      final response = await dio.post<Map<String, dynamic>>(
        refreshPath,
        data: <String, dynamic>{'refresh_token': current.refreshToken},
      );
      final data = response.data ?? <String, dynamic>{};
      final state = CwngAuthState(
        accessToken: data['access_token'] as String? ?? data['token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String? ?? current.refreshToken,
        expiresAt: _parseExpiry(data),
      );
      await _persist(state);
      return state;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> logout() async {
    await tokenStore.delete(_tokenKey);
    await tokenStore.delete(_refreshKey);
    await tokenStore.delete(_expiryKey);
  }

  Future<void> _persist(CwngAuthState state) async {
    await tokenStore.write(_tokenKey, state.accessToken);
    if (state.refreshToken != null) {
      await tokenStore.write(_refreshKey, state.refreshToken!);
    }
    if (state.expiresAt != null) {
      await tokenStore.write(_expiryKey, state.expiresAt!.toIso8601String());
    }
  }

  DateTime? _parseExpiry(Map<String, dynamic> data) {
    final raw = data['expires_at'] ?? data['expiresAt'] ?? data['expiry'];
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    final expiresIn = data['expires_in'];
    if (expiresIn is int) {
      return DateTime.now().add(Duration(seconds: expiresIn));
    }
    return null;
  }

  CwngException _mapError(DioException e) {
    final type = e.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return CwngException(CwngErrorKind.network, e.message ?? 'Network error', cause: e);
    }
    final status = e.response?.statusCode;
    if (status == 401) {
      return CwngException(CwngErrorKind.authentication, 'Invalid credentials', statusCode: status, cause: e);
    }
    if (status == 403) {
      return CwngException(CwngErrorKind.authorization, 'Forbidden', statusCode: status, cause: e);
    }
    if (status == 404) {
      return CwngException(CwngErrorKind.notFound, 'Not found', statusCode: status, cause: e);
    }
    if (status != null && status >= 500) {
      return CwngException(CwngErrorKind.server, 'Server error', statusCode: status, cause: e);
    }
    if (e.type == DioExceptionType.badCertificate) {
      return CwngException(CwngErrorKind.tls, 'TLS/certificate failure', statusCode: status, cause: e);
    }
    return CwngException(CwngErrorKind.unknown, e.message ?? 'Unknown error', statusCode: status, cause: e);
  }
}
