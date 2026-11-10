import 'dart:io';

import 'package:flutter/services.dart';

/// Loopback server for the Foliate host page, its modules, and one EPUB.
///
/// foliate-js `open(url)` fetches the whole EPUB into a blob. Streaming the
/// HTTP body avoids a second Dart copy, but the library still holds the file.
class LocalReaderServer {
  LocalReaderServer({required this.epubFile});

  final File epubFile;
  HttpServer? _server;

  int get port => _server?.port ?? 0;

  String get bookUrl => 'http://127.0.0.1:$port/book.epub';

  String get hostUrl => 'http://127.0.0.1:$port/foliate/host.html';

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path == '/book.epub') {
        if (!epubFile.existsSync()) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType('application', 'epub+zip');
        await request.response.addStream(epubFile.openRead());
        await request.response.close();
        return;
      }
      if (!path.startsWith('/foliate/') || path.contains('..')) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      final asset = 'assets$path';
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      request.response.headers.contentType = _type(path);
      request.response.add(bytes);
      await request.response.close();
    } on Object {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  ContentType _type(String path) {
    if (path.endsWith('.js')) return ContentType('text', 'javascript', charset: 'utf-8');
    if (path.endsWith('.html')) return ContentType('text', 'html', charset: 'utf-8');
    return ContentType.binary;
  }
}
