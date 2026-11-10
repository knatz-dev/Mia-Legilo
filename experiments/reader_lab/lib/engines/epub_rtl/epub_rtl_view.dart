import 'package:benchmark_core/benchmark_core.dart';
import 'package:epub_rtl/epub_rtl.dart';
import 'package:flutter/material.dart';

import '../../engine_profiles.dart';
import '../../theme.dart';

/// Callback surface for the epub_rtl view. The widget owns the book.
class EpubRtlHandle {
  EpubRtlHandle(this._state);

  final EpubRtlViewState _state;

  Future<void> navigate(ReadingLocation location) => _state.navigate(location);

  ReadingLocation? currentLocation() => _state.currentLocation();
}

class EpubRtlView extends StatefulWidget {
  const EpubRtlView({
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
  final ValueChanged<EpubRtlHandle>? onHandle;

  @override
  EpubRtlViewState createState() => EpubRtlViewState();
}

class EpubRtlViewState extends State<EpubRtlView> {
  EpubBook? _book;
  Object? _error;
  final EpubReaderController _controller = EpubReaderController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_publish);
    widget.onHandle?.call(EpubRtlHandle(this));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isAttached) _publish();
    });
    try {
      _book = EpubBook.openFile(widget.filePath, lenient: true);
    } on Object catch (error) {
      _error = error;
    }
  }

  @override
  void didUpdateWidget(EpubRtlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _book?.close();
      try {
        _book = EpubBook.openFile(widget.filePath, lenient: true);
        _error = null;
      } on Object catch (error) {
        _book = null;
        _error = error;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_publish);
    _controller.dispose();
    _book?.close();
    super.dispose();
  }

  ReadingLocation? currentLocation() {
    if (!_controller.isAttached) return null;
    return _toLocation(_controller.location);
  }

  Future<void> navigate(ReadingLocation location) async {
    final element = location.nativeLocator?['element'];
    final fraction = location.nativeLocator?['fraction'];
    await _controller.jumpTo(
      EpubLocation(
        spineIndex: location.spineIndex ?? 0,
        elementIndex: element is num ? element.toInt() : 0,
        fraction: fraction is num ? fraction.toDouble() : 0,
      ),
    );
  }

  void _publish() {
    if (!mounted || !_controller.isAttached) return;
    final native = _controller.location;
    widget.onLocation(_toLocation(native));
    final book = _book;
    if (book != null) {
      widget.onChapterLabel(_chapterTitle(book, native.spineIndex));
    }
  }

  ReadingLocation _toLocation(EpubLocation native) {
    return ReadingLocation(
      engineId: epubRtlProfile.id,
      precision: LocationPrecision.exact,
      spineIndex: native.spineIndex,
      nativeLocator: {
        'spine': native.spineIndex,
        'element': native.elementIndex,
        'fraction': native.fraction,
        'fractionRole': 'within-block layout hint, not the bookmark identity',
        'encoding': native.encode(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final book = _book;
    if (error != null) {
      return _message('epub_rtl could not open this EPUB: $error');
    }
    if (book == null) return _message('epub_rtl has no book.');
    return EpubReaderView(
      book: book,
      controller: _controller,
      mode: EpubReaderMode.scroll,
      settings: epubRtlSettings(widget.preferences),
      initialLocation: _initial(widget.initialLocation),
      onLocationChanged: (_) => _publish(),
    );
  }

  EpubLocation? _initial(ReadingLocation? location) {
    if (location == null || location.engineId != epubRtlProfile.id) return null;
    final element = location.nativeLocator?['element'];
    final fraction = location.nativeLocator?['fraction'];
    return EpubLocation(
      spineIndex: location.spineIndex ?? 0,
      elementIndex: element is num ? element.toInt() : 0,
      fraction: fraction is num ? fraction.toDouble() : 0,
    );
  }

  String _chapterTitle(EpubBook book, int spine) {
    final title = _findTitle(book, book.navigation.toc, spine);
    return title ?? 'Spine ${spine + 1}';
  }

  String? _findTitle(EpubBook book, List<EpubNavItem> items, int spine) {
    for (final item in items) {
      final href = item.href;
      if (href != null && book.spineIndexOfHref(href) == spine) return item.title;
      final nested = _findTitle(book, item.children, spine);
      if (nested != null) return nested;
    }
    return null;
  }

  Widget _message(String text) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
      );
}
