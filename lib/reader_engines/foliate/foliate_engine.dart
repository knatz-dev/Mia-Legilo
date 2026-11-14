import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../reader_engine.dart';
import '../../domain/domain.dart';

/// Foliate-js backed reader engine (prototype).
class FoliateEngine implements ReaderEngine {
  FoliateEngine() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FoliateBridge', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          // ignore: avoid_print
          print('FoliateEngine page finished: $url');
        },
      ));
  }

  late final WebViewController _controller;
  final _locationController = StreamController<ReadingLocator>.broadcast();

  WebViewController get controller => _controller;

  static const String _assetBase = 'http://10.0.2.2:8080/foliate';

  Future<void> initialize() async {
    final sw = Stopwatch()..start();
    await _controller.loadRequest(Uri.parse('$_assetBase/reader.html'));
    await Future<void>.delayed(const Duration(seconds: 2));
    sw.stop();
    // ignore: avoid_print
    print('FoliateEngine.initialize: ${sw.elapsedMilliseconds}ms');
  }

  @override
  Future<void> load(String source) async {
    final uri = Uri.parse('$_assetBase/reader.html?url=${Uri.encodeComponent(source)}');
    await _controller.loadRequest(uri);
    await Future<void>.delayed(const Duration(seconds: 3));
    await _controller.runJavaScript('''
      fetch(${jsonEncode(source)}).then(r => console.log('FETCH_TEST status=' + r.status + ' type=' + (r.headers.get('content-type')||'none'))).catch(e => console.log('FETCH_TEST err=' + e));
    ''');
  }

  @override
  Stream<ReadingLocator> get onLocationChanged => _locationController.stream;

  @override
  Future<void> goNext() async {
    await _controller.runJavaScript('try { window.reader && window.reader.view && window.reader.view.goRight(); } catch(e){}');
  }

  @override
  Future<void> goPrev() async {
    await _controller.runJavaScript('try { window.reader && window.reader.view && window.reader.view.goLeft(); } catch(e){}');
  }

  @override
  Future<void> search(String query) async {
    await _controller.runJavaScript('try { window.reader && window.reader.view && window.reader.view.search && window.reader.view.search(${jsonEncode(query)}); } catch(e){}');
  }

  @override
  Future<void> addBookmark() async {
    await _controller.runJavaScript('try { FoliateBridge.postMessage(JSON.stringify({type:"bookmark", payload:{}})); } catch(e){}');
  }

  @override
  Future<void> goTo(ReadingLocator locator) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (window.reader && typeof window.reader.goTo === 'function') {
            window.reader.goTo(${jsonEncode(locator.toJson())});
          }
        } catch (e) {}
      })();
    ''');
  }

  @override
  Future<void> setTypography({double? fontSize, double? lineHeight, double? margin}) async {
    await _controller.runJavaScript('''
      (function() {
        try {
          if (window.reader && typeof window.reader.setTypography === 'function') {
            window.reader.setTypography({fontSize: $fontSize, lineHeight: $lineHeight, margin: $margin});
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
          if (window.reader && typeof window.reader.setTheme === 'function') {
            window.reader.setTheme('$theme');
          }
        } catch (e) {}
      })();
    ''');
  }

  @override
  Future<void> dispose() async {
    await _locationController.close();
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message) as Map<String, dynamic>;
      final msg = BridgeMessage.fromJson(decoded);
      if (msg.type == 'location') {
        final p = msg.payload ?? <String, dynamic>{};
        _locationController.add(ReadingLocator(
          cfi: p['cfi'] as String?,
          anchor: p['anchor'] as String?,
          percentage: (p['percentage'] as num?)?.toDouble(),
          precision: LocatorPrecision.values.firstWhere(
            (e) => e.name == p['precision'],
            orElse: () => LocatorPrecision.approximate,
          ),
        ));
      }
    } catch (_) {
      // ignore malformed messages
    }
  }
}
