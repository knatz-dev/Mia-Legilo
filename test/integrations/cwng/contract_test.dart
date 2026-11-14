import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mia_legilo/domain/domain.dart';
import 'package:mia_legilo/integrations/cwng/cwng.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

void main() {
  group('CwngCapabilityProbe', () {
    test('marks books read-only when list endpoint reachable', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async => _json(200, <String, dynamic>{'items': <dynamic>[]}));
      final client = CwngClient(baseUrl: 'https://example.com', authenticator: CwngAuthenticator(dio: dio, tokenStore: InMemoryTokenStore(), baseUrl: 'https://example.com'), dio: dio);
      final probe = CwngCapabilityProbe(client: client);
      final state = const CwngAuthState(accessToken: 't');
      final matrix = await probe.probe(state);
      expect(matrix.stateOf(CapabilityResource.books), CapabilityState.readOnly);
    });

    test('marks books unsupported when list endpoint fails', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async => _json(404, <String, dynamic>{}));
      final client = CwngClient(baseUrl: 'https://example.com', authenticator: CwngAuthenticator(dio: dio, tokenStore: InMemoryTokenStore(), baseUrl: 'https://example.com'), dio: dio);
      final probe = CwngCapabilityProbe(client: client);
      final state = const CwngAuthState(accessToken: 't');
      final matrix = await probe.probe(state);
      expect(matrix.stateOf(CapabilityResource.books), CapabilityState.unsupported);
    });
  });

  group('CwngLibraryProvider', () {
    test('browseBooks maps items', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _FakeAdapter((opts) async => _json(200, <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{'id': '1', 'title': 'Book One', 'authors': <dynamic>['Alice']},
            ],
          }));
      final auth = CwngAuthenticator(dio: dio, tokenStore: InMemoryTokenStore(), baseUrl: 'https://example.com');
      final client = CwngClient(baseUrl: 'https://example.com', authenticator: auth, dio: dio);
      final provider = CwngLibraryProvider(
        instanceId: const ProviderInstanceId('p1'),
        authenticator: auth,
        client: client,
      );
      client.attachAuth(const CwngAuthState(accessToken: 't'));
      final books = await provider.browseBooks();
      expect(books.length, 1);
      expect(books.first.title, 'Book One');
      expect(books.first.authors, contains('Alice'));
    });
  });
}
