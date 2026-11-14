import 'package:xml/xml.dart';

import '../../domain/domain.dart';
import 'cwng_auth.dart';
import 'cwng_client.dart';
import 'cwng_capability_probe.dart';
import 'cwng_errors.dart';

/// CWNG implementation of [LibraryProvider]. Parsing is best-effort and
/// provisional; fields not present are left null (INT-012).
class CwngLibraryProvider implements LibraryProvider {
  CwngLibraryProvider({
    required this.instanceId,
    required this.authenticator,
    required this.client,
  });

  @override
  final ProviderInstanceId instanceId;

  final CwngAuthenticator authenticator;
  final CwngClient client;

  CapabilityMatrix _capabilities = CapabilityMatrix.allUnknown();

  @override
  CapabilityMatrix get capabilities => _capabilities;

  CwngAuthState? _auth;

  Future<void> authenticate(CwngCredentials credentials) async {
    _auth = await authenticator.login(credentials);
    client.attachAuth(_auth!);
    await refreshCapabilities();
  }

  @override
  Future<CapabilityMatrix> refreshCapabilities() async {
    if (_auth == null) return _capabilities;
    final probe = CwngCapabilityProbe(client: client);
    _capabilities = await probe.probe(_auth!);
    return _capabilities;
  }

  @override
  Future<List<Book>> browseBooks({int page = 0, int pageSize = 50}) async {
    // CWNG exposes OPDS (Atom). Browse the alphabetical books feed.
    final resp = await client.get<String>('/opds/books');
    final body = resp.data ?? '';
    final doc = XmlDocument.parse(body);
    final entries = doc.findAllElements('entry');
    final books = <Book>[];
    for (final entry in entries) {
      final title = entry.getElement('title')?.innerText ?? 'Unknown';
      final id = entry.getElement('id')?.innerText ?? '';
      final author = entry.findAllElements('name').map((e) => e.innerText).toList();
      // acquisition link
      String? downloadHref;
      for (final link in entry.findAllElements('link')) {
        final rel = link.getAttribute('rel') ?? '';
        if (rel.contains('acquisition')) {
          downloadHref = link.getAttribute('href');
        }
      }
      books.add(Book(
        id: BookId(id.isEmpty ? title : id),
        title: title,
        authors: author.isEmpty ? const <String>[] : author,
        remoteIdentity: RemoteIdentity(
          providerInstanceId: instanceId,
          remoteBookId: RemoteBookId(id.isEmpty ? title : id),
        ),
      ));
      // stash download href in coverPath? no; ignore for now
      if (downloadHref != null) {
        // no field; could store later
      }
    }
    return books;
  }

  @override
  Future<Book?> fetchBook(RemoteIdentity remote) async {
    try {
      final resp = await client.get<Map<String, dynamic>>('/api/books/${remote.remoteBookId.value}');
      if (resp.data == null) return null;
      return _mapBook(resp.data!);
    } on CwngException catch (e) {
      if (e.kind == CwngErrorKind.notFound) return null;
      rethrow;
    }
  }

  @override
  Future<String> downloadBook(RemoteIdentity remote, String destinationPath) async {
    // Uses dio download; endpoint provisional.
    await client.dio.download(
      '/api/books/${remote.remoteBookId.value}/download',
      destinationPath,
    );
    return destinationPath;
  }

  Book _mapBook(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['book_id']?.toString() ?? '';
    final title = json['title'] as String? ?? 'Unknown';
    final authors = (json['authors'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e.toString())
        .toList();
    return Book(
      id: BookId(id.isEmpty ? 'unknown' : id),
      title: title,
      authors: authors,
      series: json['series'] as String?,
      seriesIndex: (json['series_index'] as num?)?.toDouble(),
      description: json['description'] as String?,
      coverPath: json['cover'] as String?,
      remoteIdentity: RemoteIdentity(
        providerInstanceId: instanceId,
        remoteBookId: RemoteBookId(id.isEmpty ? 'unknown' : id),
      ),
    );
  }
}
