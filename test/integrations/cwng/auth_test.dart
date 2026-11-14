import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mia_legilo/integrations/cwng/cwng.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) => ResponseBody.fromString(
      _encode(body),
      status,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

String _encode(Map<String, dynamic> body) {
  // minimal JSON encoder
  final pairs = body.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
  return '{$pairs}';
}

void main() {
  group('CwngAuthenticator', () {
    test('login success persists token', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async {
        expect(opts.path, '/api/auth/login');
        return _json(200, <String, dynamic>{
          'access_token': 'tok123',
          'refresh_token': 'ref456',
          'expires_in': 3600,
        });
      });
      final store = InMemoryTokenStore();
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      final creds = const CwngCredentials(username: 'user', password: 'pass');
      final state = await auth.login(creds);
      expect(state.accessToken, 'tok123');
      expect(state.refreshToken, 'ref456');
      expect(await store.read('cwng_access_token'), 'tok123');
    });

    test('login 401 throws authentication', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async => _json(401, <String, dynamic>{}));
      final store = InMemoryTokenStore();
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      expect(
        () => auth.login(const CwngCredentials(username: 'u', password: 'p')),
        throwsA(isA<CwngException>().having((e) => e.kind, 'kind', CwngErrorKind.authentication)),
      );
    });

    test('restore returns null when no token', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final store = InMemoryTokenStore();
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      expect(await auth.restore(), isNull);
    });

    test('restore returns persisted state', () async {
      final store = InMemoryTokenStore();
      await store.write('cwng_access_token', 'tok');
      await store.write('cwng_refresh_token', 'ref');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      final state = await auth.restore();
      expect(state?.accessToken, 'tok');
      expect(state?.refreshToken, 'ref');
    });

    test('logout clears tokens', () async {
      final store = InMemoryTokenStore();
      await store.write('cwng_access_token', 'tok');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      await auth.logout();
      expect(await store.read('cwng_access_token'), isNull);
    });

    test('TLS failure maps to tls', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.badCertificate,
          message: 'cert bad',
        );
      });
      final store = InMemoryTokenStore();
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      expect(
        () => auth.login(const CwngCredentials(username: 'u', password: 'p')),
        throwsA(isA<CwngException>().having((e) => e.kind, 'kind', CwngErrorKind.tls)),
      );
    });

    test('network timeout maps to network', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionTimeout,
          message: 'timeout',
        );
      });
      final store = InMemoryTokenStore();
      final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: 'https://example.com');
      expect(
        () => auth.login(const CwngCredentials(username: 'u', password: 'p')),
        throwsA(isA<CwngException>().having((e) => e.kind, 'kind', CwngErrorKind.network)),
      );
    });
  });
}
