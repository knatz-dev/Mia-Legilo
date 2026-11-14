import 'package:dio/dio.dart';

import 'cwng_auth.dart';
import 'cwng_endpoints.dart';
import 'cwng_errors.dart';

/// Provider-neutral-ish CWNG client. Auth token is injected via interceptor.
class CwngClient {
  CwngClient({
    required this.baseUrl,
    required this.authenticator,
    Dio? dio,
    this.inventory = defaultCwngInventory,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  final String baseUrl;
  final CwngAuthenticator authenticator;
  final CwngEndpointInventory inventory;
  final Dio _dio;

  Dio get dio => _dio;

  /// Attach bearer token from current auth state.
  void attachAuth(CwngAuthState state) {
    _dio.options.headers['Authorization'] = 'Bearer ${state.accessToken}';
  }

  void detachAuth() {
    _dio.options.headers.remove('Authorization');
  }

  /// Generic GET with error mapping.
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _dio.get<T>(path, queryParameters: query);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// Generic POST with error mapping.
  Future<Response<T>> post<T>(String path, {Object? data}) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  CwngException _map(DioException e) {
    final status = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return CwngException(CwngErrorKind.network, e.message ?? 'Network error', cause: e);
    }
    if (status == 401) {
      return CwngException(CwngErrorKind.authentication, 'Unauthorized', statusCode: status, cause: e);
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
      return CwngException(CwngErrorKind.tls, 'TLS failure', statusCode: status, cause: e);
    }
    return CwngException(CwngErrorKind.unknown, e.message ?? 'Unknown', statusCode: status, cause: e);
  }
}
