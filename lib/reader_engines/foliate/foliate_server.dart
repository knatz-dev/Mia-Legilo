import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';

/// Loopback-only HTTP origin serving the vendored Foliate-js renderer and the
/// EPUB files the reader has been asked to open.
///
/// WebViews refuse to load ES modules from `file://`/`asset://` origins, so the
/// renderer needs an HTTP origin. Serving it from inside the app keeps the
/// reader fully offline (no dev host, no `10.0.2.2`) and makes the harness page
/// same-origin with the book, so `fetch()` and `import()` inside the page work.
class FoliateServer {
  FoliateServer._(this._server);

  final HttpServer _server;
  final Map<String, File> _books = <String, File>{};
  int _nextBookId = 0;

  /// Unguessable per-session secret. The book URL is handed to the WebView, so
  /// it also has to stop any other app on the device from fetching the open
  /// EPUB off the loopback port.
  final String _token = _randomToken();

  static const String _assetRoot = 'reader_engines/foliate/foliate-js';
  static const String _harnessAsset = 'assets/foliate/host.html';

  static const Map<String, String> _contentTypes = <String, String>{
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'svg': 'image/svg+xml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'epub': 'application/epub+zip',
  };

  int get port => _server.port;

  Uri get origin => Uri(scheme: 'http', host: '127.0.0.1', port: port);

  /// URL of the renderer harness page.
  Uri get harnessUri => origin.replace(path: '/foliate/host.html');

  /// Binds an ephemeral port on the loopback interface and starts serving.
  static Future<FoliateServer> start() async {
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final FoliateServer foliate = FoliateServer._(server);
    server.listen(foliate._handle, onError: (Object _) {});
    return foliate;
  }

  /// Makes [file] available to the renderer and returns its URL.
  Uri registerBook(File file) {
    final String id = 'book-${_nextBookId++}';
    _books[id] = file;
    return origin.replace(path: '/books/$id', queryParameters: <String, String>{
      'token': _token,
    });
  }

  Future<void> close() async {
    _books.clear();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    try {
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      // Loopback origin only: the renderer is same-origin with the harness, so
      // a wildcard CORS grant buys nothing and would expose the book to any
      // page that can reach the port.
      response.headers.set('Access-Control-Allow-Origin', origin.toString());
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (request.uri.queryParameters['token'] != _token &&
          request.uri.pathSegments.first == 'books') {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final List<String> segments = request.uri.pathSegments;
      if (segments.isEmpty) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (segments.first == 'foliate') {
        await _serveRenderer(request, response, segments.sublist(1));
        return;
      }
      if (segments.first == 'books' && segments.length == 2) {
        await _serveBook(request, response, segments[1]);
        return;
      }
      response.statusCode = HttpStatus.notFound;
    } catch (e) {
      // A closed or aborted WebView request must not take the app down.
      try {
        response.statusCode = HttpStatus.internalServerError;
      } catch (_) {
        // Response already closed.
      }
      // ignore: avoid_print
      print('FoliateServer error: $e');
    } finally {
      try {
        await response.close();
      } catch (_) {
        // Client hung up.
      }
    }
  }

  Future<void> _serveRenderer(
    HttpRequest request,
    HttpResponse response,
    List<String> segments,
  ) async {
    if (segments.isEmpty) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    if (segments.contains('..')) {
      response.statusCode = HttpStatus.forbidden;
      return;
    }
    final String name = segments.join('/');
    final String asset =
        name == 'host.html' ? _harnessAsset : '$_assetRoot/$name';
    try {
      final ByteData data = await rootBundle.load(asset);
      _send(
        request,
        response,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        _contentTypeFor(name),
      );
    } on FlutterError {
      response.statusCode = HttpStatus.notFound;
    }
  }

  Future<void> _serveBook(
    HttpRequest request,
    HttpResponse response,
    String id,
  ) async {
    final File? file = _books[id];
    if (file == null || !await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    final int length = await file.length();
    response.headers.contentType = ContentType.parse(_contentTypes['epub']!);
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.contentLength = length;
    if (request.method == 'GET') {
      await response.addStream(file.openRead());
    }
  }

  void _send(
    HttpRequest request,
    HttpResponse response,
    Uint8List bytes,
    String contentType,
  ) {
    response.headers.contentType = ContentType.parse(contentType);
    response.contentLength = bytes.length;
    if (request.method == 'GET') response.add(bytes);
  }

  static String _contentTypeFor(String name) {
    final int dot = name.lastIndexOf('.');
    final String extension =
        dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    return _contentTypes[extension] ?? 'application/octet-stream';
  }

  static String _randomToken() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
