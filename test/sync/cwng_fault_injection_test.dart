import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_legilo/integrations/cwng/cwng.dart';
import 'package:mia_legilo/domain/capability.dart';

void main() {
  group('CWNG fault injection', () {
    HttpServer? server;

    tearDown(() async {
      await server?.close(force: true);
    });

    test('network drop: connection refused', () async {
      // Use a port that nothing is listening on.
      final dio = Dio(BaseOptions(
        baseUrl: 'http://127.0.0.1:19999',
        connectTimeout: const Duration(seconds: 2),
      ));
      final client = CwngClient(
        baseUrl: 'http://127.0.0.1:19999',
        authenticator: CwngAuthenticator(
          dio: dio,
          tokenStore: _InMemoryTokenStore(),
          baseUrl: 'http://127.0.0.1:19999',
        ),
      );
      expect(
        () => client.get('/opds'),
        throwsA(isA<CwngException>()),
      );
    });

    test('server 5xx returns server error', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serve500(server!));
      final dio = Dio(BaseOptions(baseUrl: 'http://${server!.address.host}:${server!.port}'));
      final client = CwngClient(
        baseUrl: 'http://${server!.address.host}:${server!.port}',
        authenticator: CwngAuthenticator(
          dio: dio,
          tokenStore: _InMemoryTokenStore(),
          baseUrl: 'http://${server!.address.host}:${server!.port}',
        ),
      );
      final auth = CwngAuthState(accessToken: 'dGVzdDp0ZXN0', scheme: 'basic');
      client.attachAuth(auth);
      expect(
        () => client.get('/opds'),
        throwsA(isA<CwngException>().having(
          (CwngException e) => e.kind,
          'kind',
          CwngErrorKind.server,
        )),
      );
    });

    test('auth expiry returns authentication error', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serve401(server!));
      final dio = Dio(BaseOptions(baseUrl: 'http://${server!.address.host}:${server!.port}'));
      final client = CwngClient(
        baseUrl: 'http://${server!.address.host}:${server!.port}',
        authenticator: CwngAuthenticator(
          dio: dio,
          tokenStore: _InMemoryTokenStore(),
          baseUrl: 'http://${server!.address.host}:${server!.port}',
        ),
      );
      final auth = CwngAuthState(accessToken: 'dGVzdDp0ZXN0', scheme: 'basic');
      client.attachAuth(auth);
      expect(
        () => client.get('/opds'),
        throwsA(isA<CwngException>().having(
          (CwngException e) => e.kind,
          'kind',
          CwngErrorKind.authentication,
        )),
      );
    });

    test('capability probe marks status read-only on 401', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serve401(server!));
      final dio = Dio(BaseOptions(baseUrl: 'http://${server!.address.host}:${server!.port}'));
      final client = CwngClient(
        baseUrl: 'http://${server!.address.host}:${server!.port}',
        authenticator: CwngAuthenticator(
          dio: dio,
          tokenStore: _InMemoryTokenStore(),
          baseUrl: 'http://${server!.address.host}:${server!.port}',
        ),
      );
      final auth = CwngAuthState(accessToken: 'dGVzdDp0ZXN0', scheme: 'basic');
      final probe = CwngCapabilityProbe(client: client);
      final caps = await probe.probe(auth);
      expect(caps.stateOf(CapabilityResource.status), CapabilityState.readOnly);
    });

    test('capability probe marks status readWrite on 404', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(_serve404(server!));
      final dio = Dio(BaseOptions(baseUrl: 'http://${server!.address.host}:${server!.port}'));
      final client = CwngClient(
        baseUrl: 'http://${server!.address.host}:${server!.port}',
        authenticator: CwngAuthenticator(
          dio: dio,
          tokenStore: _InMemoryTokenStore(),
          baseUrl: 'http://${server!.address.host}:${server!.port}',
        ),
      );
      final auth = CwngAuthState(accessToken: 'dGVzdDp0ZXN0', scheme: 'basic');
      final probe = CwngCapabilityProbe(client: client);
      final caps = await probe.probe(auth);
      expect(caps.stateOf(CapabilityResource.status), CapabilityState.readWrite);
    });
  });
}

Future<void> _serve500(HttpServer server) async {
  await for (final HttpRequest request in server) {
    request.response.statusCode = 500;
    await request.response.close();
  }
}

Future<void> _serve401(HttpServer server) async {
  await for (final HttpRequest request in server) {
    request.response.statusCode = 401;
    await request.response.close();
  }
}

Future<void> _serve404(HttpServer server) async {
  await for (final HttpRequest request in server) {
    request.response.statusCode = 404;
    await request.response.close();
  }
}

class _InMemoryTokenStore implements TokenStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
