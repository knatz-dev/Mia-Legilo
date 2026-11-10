import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

import '../../engine_profiles.dart';
import '../../theme.dart';

class EpubJsHandle {
  EpubJsHandle(this._state);

  final EpubJsViewState _state;

  Future<void> navigate(ReadingLocation location) => _state.navigate(location);
}

class EpubJsView extends StatefulWidget {
  const EpubJsView({
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
  final ValueChanged<EpubJsHandle>? onHandle;

  @override
  EpubJsViewState createState() => EpubJsViewState();
}

class EpubJsViewState extends State<EpubJsView> {
  final EpubController _controller = EpubController();
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.onHandle?.call(EpubJsHandle(this));
  }

  @override
  void didUpdateWidget(EpubJsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loaded && oldWidget.preferences != widget.preferences) {
      _applyPreferences();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> navigate(ReadingLocation location) async {
    final cfi = location.epubCfi;
    if (cfi == null || cfi.isEmpty) return;
    _controller.display(cfi: cfi);
  }

  Future<void> _applyPreferences() async {
    await _controller.setFontSize(fontSize: widget.preferences.fontSize);
    await _controller.updateTheme(theme: epubJsTheme(widget.preferences));
    if (widget.preferences.reducedMotion) {
      await _controller.setFlow(flow: EpubFlow.scrolled);
    }
  }

  ReadingLocation _fromPackage(EpubLocation value) {
    final cfi = value.startCfi.trim().isEmpty ? null : value.startCfi;
    return ReadingLocation(
      engineId: epubJsProfile.id,
      precision: cfi == null ? LocationPrecision.approximate : LocationPrecision.exact,
      epubCfi: cfi,
      progress: value.progress,
      nativeLocator: {
        'startCfi': value.startCfi,
        'endCfi': value.endCfi,
        'startXpath': value.startXpath,
        'endXpath': value.endXpath,
        'progress': value.progress,
        'progressRole': 'approximate whole-book fraction, not the bookmark identity',
        'chapterPage': value.chapterPage,
        'chapterTotalPages': value.chapterTotalPages,
        'printedPage': value.printedPage,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error)));
    }
    final initial = widget.initialLocation?.epubCfi;
    return Stack(
      children: [
        EpubViewer(
          epubController: _controller,
          epubSource: EpubSource.fromFile(File(widget.filePath)),
          initialCfi: initial,
          displaySettings: EpubDisplaySettings(
            flow: EpubFlow.scrolled,
            manager: EpubManager.continuous,
            snap: false,
            useSnapAnimationAndroid: false,
            allowScriptedContent: false,
            fontSize: widget.preferences.fontSize.round().clamp(10, 48),
            theme: epubJsTheme(widget.preferences),
          ),
          onEpubLoaded: () {
            if (!mounted) return;
            setState(() => _loaded = true);
            widget.onChapterLabel('Chapter title is not on the relocate event');
          },
          onLoadError: (loadError) {
            if (!mounted) return;
            setState(() => _error = 'flutter_epub_viewer: ${loadError.message}');
          },
          onRelocated: (value) => widget.onLocation(_fromPackage(value)),
          onChaptersLoaded: (chapters) {
            if (chapters.isEmpty) return;
            widget.onChapterLabel(chapters.first.title);
          },
        ),
        if (!_loaded)
          const ColoredBox(
            color: Color(0xCCFFFFFF),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
