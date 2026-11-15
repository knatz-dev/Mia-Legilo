import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../reader_engine.dart';
import '../../domain/domain.dart';
import 'foliate_server.dart';

/// Foliate-js backed reader engine.
///
/// The renderer is served from an in-app loopback HTTP server (see
/// [FoliateServer]) and the book is handed to it as a local URL, so nothing
/// depends on the host machine being reachable from the device.
class FoliateEngine implements ReaderEngine {
  FoliateEngine() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FoliateBridge', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (String url) {
          // ignore: avoid_print
          print('FoliateEngine page finished: $url');
        },
        onWebResourceError: (WebResourceError error) {
          // ignore: avoid_print
          print('FoliateEngine resource error: ${error.description} (${error.errorCode})');
        },
      ));
  }

  late final WebViewController _controller;
  FoliateServer? _server;
  final StreamController<ReadingLocator> _locationController =
      StreamController<ReadingLocator>.broadcast();

  /// Resolves with the book title once the renderer has opened the book.
  Completer<String>? _bookOpened;

  WebViewController get controller => _controller;

  /// Completes with the title of the book currently open.
  Future<String> get bookOpened => _bookOpened?.future ?? Future<String>.value('');

  Future<void> initialize() async {
    final Stopwatch sw = Stopwatch()..start();
    _server ??= await FoliateServer.start();
    sw.stop();
    // ignore: avoid_print
    print('FoliateEngine.initialize: ${sw.elapsedMilliseconds}ms on ${_server!.origin}');
  }

  @override
  Future<void> load(String source) async {
    final FoliateServer server = await _ensureServer();
    final File file = await _materialize(source);
    if (!await file.exists()) {
      throw FileSystemException('Book file not found', file.path);
    }
    final Uri bookUri = server.registerBook(file);
    final Uri page = server.harnessUri
        .replace(queryParameters: <String, String>{'book': bookUri.toString()});
    _bookOpened = Completer<String>();
    // ignore: avoid_print
    print('FoliateEngine.load: $page');
    await _controller.loadRequest(page);
  }

  Future<FoliateServer> _ensureServer() async {
    final FoliateServer? existing = _server;
    if (existing != null) return existing;
    await initialize();
    return _server!;
  }

  /// Local files are used as-is; remote books are downloaded once and served
  /// from the cache so the WebView never has to talk to a remote host.
  Future<File> _materialize(String source) async {
    final Uri? uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return _download(uri);
    }
    return File(source);
  }

  Future<File> _download(Uri uri) async {
    final Directory temp = await getTemporaryDirectory();
    final Directory cache = Directory(p.join(temp.path, 'downloads'));
    if (!await cache.exists()) await cache.create(recursive: true);
    final String name = uri.pathSegments.isEmpty
        ? 'book.epub'
        : uri.pathSegments.last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final File target = File(p.join(cache.path, name));
    // ignore: avoid_print
    print('FoliateEngine.download: $uri -> ${target.path}');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final IOSink sink = target.openWrite();
      await response.pipe(sink);
    } finally {
      client.close(force: true);
    }
    return target;
  }

  @override
  Stream<ReadingLocator> get onLocationChanged => _locationController.stream;

  @override
  Future<void> goNext() async {
    await _controller.runJavaScript(
      '(() => { try { const v = globalThis.view; if (!v) return; if (v.goRight) v.goRight(); else v.next(); } catch (e) {} })();',
    );
  }

  @override
  Future<void> goPrev() async {
    await _controller.runJavaScript(
      'try { globalThis.view && globalThis.view.goLeft && globalThis.view.goLeft(); } catch (e) {}',
    );
  }

  @override
  Future<void> search(String query) async {
    await _controller.runJavaScript(
      'try { globalThis.view && globalThis.view.search && globalThis.view.search(${jsonEncode(query)}); } catch (e) {}',
    );
  }

  /// Returns the table of contents exposed by foliate's book model.
  Future<List<Map<String, dynamic>>> getToc() async {
    try {
      final Object result = await _controller.runJavaScriptReturningResult(
        'JSON.stringify((globalThis.reader && globalThis.reader.book && globalThis.reader.book.toc) || [])',
      );
      final String raw = result is String ? result : result.toString();
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((Map m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  /// Navigates to an EPUB href (used by TOC entries and internal links).
  Future<void> goToHref(String href) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (globalThis.view && typeof globalThis.view.goTo === 'function') {
            globalThis.view.goTo(${jsonEncode(href)});
          } else if (globalThis.reader && typeof globalThis.reader.goTo === 'function') {
            globalThis.reader.goTo(${jsonEncode(href)});
          }
        } catch (e) {}
      })();
    ''');
  }

  @override
  Future<void> addBookmark() async {
    await _controller.runJavaScript(
      'try { FoliateBridge.postMessage(JSON.stringify({type:"bookmark", payload:{}})); } catch (e) {}',
    );
  }

  @override
  Future<void> goTo(ReadingLocator locator) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (globalThis.reader && typeof globalThis.reader.goTo === 'function') {
            globalThis.reader.goTo(${jsonEncode(locator.toJson())});
          }
        } catch (e) {}
      })();
    ''');
  }

  @override
  Future<void> setTypography({
    double? fontSize,
    double? lineHeight,
    double? margin,
  }) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (globalThis.reader && typeof globalThis.reader.setTypography === 'function') {
            globalThis.reader.setTypography({fontSize: $fontSize, lineHeight: $lineHeight, margin: $margin});
          }
        } catch (e) {}
      })();
    ''');
  }

  /// Switches the renderer between continuous vertical scrolling
  /// (`scrolled`, the default) and horizontal pagination.
  Future<void> setLayout(String mode) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (globalThis.reader && typeof globalThis.reader.setLayout === 'function') {
            globalThis.reader.setLayout(${jsonEncode(mode)});
          }
        } catch (e) {}
      })();
    ''');
  }

  @override
  Future<void> setTheme(String theme) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (globalThis.reader && typeof globalThis.reader.setTheme === 'function') {
            globalThis.reader.setTheme(${jsonEncode(theme)});
          }
        } catch (e) {}
      })();
    ''');
  }

  @override
  Future<void> dispose() async {
    await _locationController.close();
    await _server?.close();
    _server = null;
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(message.message) as Map<String, dynamic>;
      final BridgeMessage msg = BridgeMessage.fromJson(decoded);
      final Map<String, dynamic> payload = msg.payload ?? <String, dynamic>{};
      switch (msg.type) {
        case 'location':
          _locationController.add(ReadingLocator(
            cfi: payload['cfi'] as String?,
            anchor: payload['anchor'] as String?,
            percentage: (payload['percentage'] as num?)?.toDouble(),
            precision: LocatorPrecision.values.firstWhere(
              (LocatorPrecision e) => e.name == payload['precision'],
              orElse: () => LocatorPrecision.approximate,
            ),
          ));
        case 'book':
          // ignore: avoid_print
          print('FoliateEngine.book: ${payload['title']} (${payload['sections']} sections)');
        case 'page':
          // ignore: avoid_print
          print('FoliateEngine.page ${payload['index']}: ${payload['text']}');
        case 'ready':
          final Completer<String>? opened = _bookOpened;
          if (opened != null && !opened.isCompleted) opened.complete('ready');
          // ignore: avoid_print
          print('FoliateEngine.ready');
        case 'error':
          // ignore: avoid_print
          print('FoliateEngine.error: ${payload['message']}');
          final Completer<String>? opened = _bookOpened;
          if (opened != null && !opened.isCompleted) {
            opened.completeError(StateError('${payload['message']}'));
          }
      }
    } catch (e) {
      // ignore: avoid_print
      print('FoliateEngine bridge parse error: $e');
    }
  }
}
