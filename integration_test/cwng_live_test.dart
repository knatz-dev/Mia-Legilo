import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mia_legilo/domain/domain.dart';
import 'package:mia_legilo/integrations/cwng/cwng.dart';

void main() {
  final baseUrl = Platform.environment['CWNG_BASE_URL'] ?? 'https://library.knatz.dev';
  final username = Platform.environment['CWNG_USERNAME'];
  final password = Platform.environment['CWNG_PASSWORD'];

  test('live CWNG capability probe', () async {
    if (username == null || password == null) {
      // ignore: avoid_print
      print('Skipping live test: set CWNG_USERNAME and CWNG_PASSWORD.');
      return;
    }

    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final store = InMemoryTokenStore();
    final auth = CwngAuthenticator(dio: dio, tokenStore: store, baseUrl: baseUrl);
    final state = await auth.login(CwngCredentials(username: username, password: password));
    // ignore: avoid_print
    print('Authenticated: ${state.accessToken.isNotEmpty}');

    final client = CwngClient(baseUrl: baseUrl, authenticator: auth, dio: dio);
    client.attachAuth(state);

    final probe = CwngCapabilityProbe(client: client);
    final matrix = await probe.probe(state);
    for (final r in CapabilityResource.values) {
      // ignore: avoid_print
      print('${r.name}: ${matrix.stateOf(r).name}');
    }

    final provider = CwngLibraryProvider(
      instanceId: const ProviderInstanceId('live'),
      authenticator: auth,
      client: client,
    );
    final books = await provider.browseBooks(pageSize: 5);
    // ignore: avoid_print
    print('Browsed ${books.length} books');
    expect(books, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
