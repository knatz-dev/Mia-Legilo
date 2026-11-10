import 'dart:convert';
import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../engine_profiles.dart';
import '../../theme.dart';
import 'local_reader_server.dart';

class FoliateHandle {
  FoliateHandle(this._state);

  final FoliateViewState _state;

  Future<void> navigate(ReadingLocation location) => _state.navigate(location);
}

class FoliateView extends StatefulWidget {
  const FoliateView({
    super.key,
    required this.filePath,
    required this.preferences,
    required this.onLocation,
    required this.onChapterLabel,
    this.initialLocation,
    this.onHandle,
  });

  final String filePath;
  final ReaderPreferences preferences;
  final ReadingLocation? initialLocation;
  final ValueChanged<ReadingLocation> onLocation;
  final ValueChanged<String> onChapterLabel;
  final ValueChanged<FoliateHandle>? onHandle;

  @override
  FoliateViewState createState() => FoliateViewState();
}

class FoliateViewState extends State<FoliateView> {
  LocalReaderServer? _server;
  InAppWebViewController? _web;
  String? _error;
  var _ready = false;
  var _opened = false;

  @override
  void initState() {
    super.initState();
    widget.onHandle?.call(FoliateHandle(this));
    _start();
  }

  @override
  void didUpdateWidget(FoliateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_opened && oldWidget.preferences != widget.preferences) {
      _pushPreferences();
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final server = LocalReaderServer(epubFile: File(widget.filePath));
      await server.start();
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() => _server = server);
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Foliate local server failed: $error');
    }
  }

  Future<void> navigate(ReadingLocation location) async {
    final cfi = location.epubCfi;
    final controller = _web;
    if (cfi == null || controller == null) return;
    await controller.evaluateJavascript(
      source: 'window.readerLab.goTo(${jsonEncode(cfi)})',
    );
  }

  Future<void> _pushPreferences() async {
    final controller = _web;
    if (controller == null) return;
    final payload = jsonEncode(foliatePreferencePayload(widget.preferences));
    await controller.evaluateJavascript(
      source: 'window.readerLab.setPreferences($payload)',
    );
  }

  Future<void> _openBook() async {
    final controller = _web;
    final server = _server;
    if (controller == null || server == null || _opened) return;
    final cfi = widget.initialLocation?.engineId == foliateProfile.id
        ? widget.initialLocation?.epubCfi
        : null;
    await controller.evaluateJavascript(
      source:
          'window.readerLab.open(${jsonEncode(server.bookUrl)}, ${jsonEncode(cfi)})',
    );
  }

  void _onMessage(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final type = decoded['type'];
    if (type == 'ready') {
      _ready = true;
      _openBook();
      _pushPreferences();
    } else if (type == 'opened') {
      _opened = true;
      final sections = decoded['sections'];
      widget.onChapterLabel(
        sections is num ? 'Spine items reported by foliate: $sections' : 'Opened',
      );
    } else if (type == 'relocate') {
      final location = decoded['location'];
      if (location is! Map) return;
      final cfi = location['cfi'] as String?;
      final fraction = location['fraction'];
      final label = location['chapterLabel'] as String?;
      if (label != null && label.isNotEmpty) widget.onChapterLabel(label);
      widget.onLocation(
        ReadingLocation(
          engineId: foliateProfile.id,
          precision:
              cfi == null || cfi.isEmpty ? LocationPrecision.approximate : LocationPrecision.exact,
          epubCfi: cfi,
          progress: fraction is num ? fraction.toDouble() : null,
          nativeLocator: {
            'cfi': cfi,
            'fraction': fraction,
            'fractionRole': 'foliate section fraction; approximate; not the identity',
            'chapterLabel': label,
          },
        ),
      );
    } else if (type == 'error') {
      setState(() => _error = '${decoded['message']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final server = _server;
    if (error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error)));
    }
    if (server == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(server.hostUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        supportZoom: false,
        verticalScrollBarEnabled: true,
        disableVerticalScroll: false,
        transparentBackground: false,
        mediaPlaybackRequiresUserGesture: true,
        allowFileAccess: false,
      ),
      onWebViewCreated: (controller) {
        _web = controller;
        controller.addJavaScriptHandler(
          handlerName: 'foliate',
          callback: (List<dynamic> args) {
            if (args.isEmpty || args.first is! String) return null;
            _onMessage(args.first as String);
            return null;
          },
        );
      },
      onLoadStop: (_, _) {
        if (_ready) return;
      },
      onReceivedError: (_, _, error) {
        if (!mounted) return;
        setState(() => _error = 'WebView error: ${error.description}');
      },
    );
  }
}
