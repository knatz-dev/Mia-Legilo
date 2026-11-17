import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../domain/annotation.dart';
import '../../domain/ids.dart';
import '../../domain/locator.dart';
import '../../domain/status.dart';
import '../../library/library_service.dart';
import '../../reader_engines/foliate/foliate_engine.dart';
import '../settings/settings_model.dart';
import '../settings/settings_pages.dart';
import '../settings/settings_service.dart';
import 'reader_settings.dart';

/// The reader. Layout, typography and theme are read from the persisted
/// reader defaults (edited in Settings → Reader); the only temporary control
/// here is the scrolled/paginated view toggle, whose saved default also lives
/// in Settings → Reader.
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    this.source,
    this.title,
    this.onFinished,
    this.initialStatus,
    this.initialStatusManual = false,
    this.onProgress,
    this.onAddBookmark,
    this.library,
    this.initialLocator,
    this.bookId,
  });

  /// Local file path or remote URL of the EPUB to display.
  final String? source;
  final String? title;
  final Future<void> Function()? onFinished;
  final ReadingStatus? initialStatus;
  final bool initialStatusManual;
  final Future<void> Function(ReadingLocator locator)? onProgress;
  final Future<void> Function(ReadingLocator locator)? onAddBookmark;
  final LibraryService? library;
  final ReadingLocator? initialLocator;
  final String? bookId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final FoliateEngine _engine;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _loadError;
  bool _paginated = false;
  bool _completionPrompted = false;
  ReadingLocator? _lastLocator;
  ReaderSettings _settings = const ReaderSettings();
  List<Map<String, dynamic>> _toc = <Map<String, dynamic>>[];
  double? _progress;
  Future<void> _locationWrites = Future<void>.value();
  StreamSubscription<ReadingLocator>? _locationSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _engine = FoliateEngine();
    _openBook();
  }

  Future<void> _openBook() async {
    final String? source = widget.source;
    if (source == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      await _engine.initialize();
      final LibraryService? library = widget.library;
      if (library != null) {
        final ReaderDefaults defaults = await SettingsService(library)
            .readerDefaults();
        _settings = ReaderSettings(
          fontSize: defaults.fontSize,
          lineHeight: defaults.lineHeight,
          margin: defaults.margin,
          theme: defaults.theme,
          layout: defaults.layout,
          highContrast: defaults.theme == 'high-contrast',
          reducedMotion: defaults.reducedMotion,
        );
      }
      await _engine.load(source);
      await _engine.bookOpened;
      if (!mounted) return;
      await _applySettings();
      _toc = await _engine.getToc();
      if (widget.initialLocator != null) {
        await _engine.goTo(widget.initialLocator!);
      }
      _lastLocator = widget.initialLocator;
      _locationSub = _engine.onLocationChanged.listen(_onLocation);
      _errorSub = _engine.onError.listen((String e) async {
        if (!mounted) return;
        final bool recovered = await _engine.recover();
        if (recovered) {
          if (!mounted) return;
          setState(() => _loading = false);
          return;
        }
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'Renderer error: $e';
        });
      });
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _errorSub?.cancel();
    _searchController.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _onLocation(ReadingLocator locator) {
    final meaningful = _lastLocator != null && _lastLocator != locator;
    _lastLocator = locator;
    _progress = locator.percentage;
    if (mounted) setState(() {});
    _locationWrites = _locationWrites
        .then((_) async {
          final library = widget.library;
          if (library != null && widget.bookId != null) {
            await library.recordProgress(
              BookId(widget.bookId!),
              locator,
              meaningful: meaningful,
            );
          }
          await widget.onProgress?.call(locator);
          if (!mounted ||
              !meaningful ||
              _completionPrompted ||
              widget.initialStatus == ReadingStatus.completed ||
              widget.initialStatusManual ||
              (locator.percentage ?? 0) < 0.995) {
            return;
          }
          if (library != null &&
              widget.bookId != null &&
              !await library.claimCompletionPrompt(BookId(widget.bookId!))) {
            return;
          }
          _completionPrompted = true;
          await _showCompletionPrompt();
        })
        .catchError((Object error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save reading state: $error')),
            );
          }
        });
  }

  Future<void> _showCompletionPrompt() async {
    if (!mounted) return;
    final bool? mark = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SketchDialog(
        title: 'Finished reading?',
        seedKey: 'finished-reading',
        content: const Text(
          'You reached the end of this book. Mark it as completed?',
          style: TextStyle(fontSize: 14, height: 1.5, color: kInk),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          SketchButton(
            label: 'Mark completed',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (mark == true) {
      await widget.onFinished?.call();
    }
  }

  Future<void> _applySettings() async {
    _paginated = _settings.layout == 'paginated';
    await _engine.setLayout(_settings.layout);
    await _engine.setTypography(
      fontSize: _settings.fontSize,
      lineHeight: _settings.lineHeight,
      margin: _settings.margin,
    );
    await _engine.setTheme(_settings.theme);
  }

  Future<void> _toggleLayout() async {
    final String layout = _paginated ? 'scrolled' : 'paginated';
    setState(() {
      _paginated = !_paginated;
      _settings = _settings.copyWith(layout: layout);
    });
    await _engine.setLayout(layout);
    final LibraryService? library = widget.library;
    if (library != null) {
      // The saved default follows the reader, so a fresh book opens the way
      // this one was last read.
      final ReaderDefaults defaults = await SettingsService(library)
          .readerDefaults();
      await SettingsService(library)
          .saveReaderDefaults(defaults.copyWith(layout: layout));
    }
  }

  void _openReaderSettings() {
    final LibraryService? library = widget.library;
    if (library == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsHost(
          service: SettingsService(library),
          child: ReaderSettingsPage(settings: SettingsService(library)),
        ),
      ),
    );
  }

  Widget _buildTocDrawer() {
    return Drawer(
      child: SafeArea(
        child: _toc.isEmpty
            ? const Center(child: Text('No table of contents'))
            : ListView.builder(
                itemCount: _toc.length,
                itemBuilder: (BuildContext ctx, int i) {
                  final Map<String, dynamic> entry = _toc[i];
                  final String label =
                      (entry['label'] ?? entry['title'] ?? 'Section')
                          .toString();
                  final String? href = entry['href'] as String?;
                  return ListTile(
                    title: Text(label),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (href != null && href.isNotEmpty) {
                        _engine.goToHref(href);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showBookmarks() async {
    if (widget.library == null || widget.bookId == null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => SketchDialog(
          title: 'Bookmarks',
          seedKey: 'bookmarks-unavailable',
          content: const Text(
            'Open this book from your library to manage bookmarks.',
            style: TextStyle(fontSize: 14, height: 1.5, color: kInk),
          ),
          actions: <Widget>[
            SketchButton(label: 'OK', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
      return;
    }
    final List<Bookmark> list = await widget.library!.bookmarksFor(
      BookId(widget.bookId!),
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SketchSheet(
        title: 'Bookmarks',
        seedKey: 'bookmarks-sheet',
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: kSpace4),
                child: Text(
                  'No bookmarks yet. Use the bookmark icon while reading.',
                  style: TextStyle(fontSize: 14, color: kInkMuted),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: list
                    .map(
                      (Bookmark bm) => SketchNavRow(
                        label: bm.label ?? 'Bookmark',
                        value: bm.locator.cfi ?? '',
                        icon: bm.locator.cfi == null
                            ? Icons.bookmark_outline
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _engine.goTo(bm.locator);
                        },
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _showSearch() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => SketchDialog(
        title: 'Search in book',
        seedKey: 'search-in-book',
        content: SketchTextField(
          label: 'Query',
          controller: _searchController,
          autofocus: true,
          seedKey: 'search-in-book-field',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          SketchButton(
            label: 'Search',
            onPressed: () {
              _engine.search(_searchController.text);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildTocDrawer(),
      appBar: AppBar(
        title: Text(widget.title ?? 'Reader', overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          SketchIconButton(
            icon: Icons.toc,
            tooltip: 'Contents',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          SketchIconButton(
            icon: _paginated ? Icons.swap_vert : Icons.auto_stories_outlined,
            tooltip: _paginated ? 'Vertical scroll' : 'Paginated',
            onPressed: _toggleLayout,
          ),
          SketchIconButton(
            icon: Icons.bookmarks_outlined,
            tooltip: 'Bookmarks',
            onPressed: _showBookmarks,
          ),
          SketchIconButton(
            icon: Icons.text_fields,
            tooltip: 'Reader settings',
            onPressed: _openReaderSettings,
          ),
          SketchIconButton(
            icon: Icons.search,
            tooltip: 'Search in book',
            onPressed: _showSearch,
          ),
          SketchIconButton(
            icon: Icons.bookmark_add_outlined,
            tooltip: 'Add bookmark',
            onPressed: () async {
              await _engine.addBookmark();
              final ReadingLocator? loc = _lastLocator;
              if (loc != null) {
                await widget.onAddBookmark?.call(loc);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _engine.controller),
          if (_loading)
            const ColoredBox(
              color: kPaper,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_loadError != null)
            ColoredBox(
              color: kPaper,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(kSpace5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: kInkMuted,
                      ),
                      const SizedBox(height: kSpace3),
                      const Text(
                        'Could not open this book',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: kSpace2),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: kInkMuted,
                        ),
                      ),
                      const SizedBox(height: kSpace4),
                      SketchButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _loadError = null;
                          });
                          _openBook();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            if (_progress != null)
              Text(
                '${(_progress! * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
            SketchIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous page',
              onPressed: _engine.goPrev,
            ),
            SketchIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Next page',
              onPressed: _engine.goNext,
            ),
          ],
        ),
      ),
    );
  }
}
