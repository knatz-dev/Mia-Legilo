import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/annotation.dart';
import '../../domain/ids.dart';
import '../../domain/locator.dart';
import '../../domain/status.dart';
import '../../library/library_service.dart';
import '../../reader_engines/foliate/foliate_engine.dart';
import 'reader_settings.dart';

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
        final String? raw = await library.store.readSetting('reader.settings');
        if (raw != null && raw.isNotEmpty) {
          _settings = ReaderSettings.fromJsonString(raw);
        }
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
        // Attempt bounded crash recovery.
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
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Finished reading?'),
        content: const Text(
          'You reached the end of this book. Mark it as completed?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark completed'),
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

  Future<void> _saveSettings() async {
    final LibraryService? library = widget.library;
    if (library == null) return;
    await library.store.writeSetting(
      'reader.settings',
      _settings.toJsonString(),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        double fontSize = _settings.fontSize;
        double lineHeight = _settings.lineHeight;
        double margin = _settings.margin;
        String theme = _settings.theme;
        String layout = _settings.layout;
        bool reducedMotion = _settings.reducedMotion;
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Typography',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Font size'),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 12,
                          max: 28,
                          divisions: 16,
                          label: fontSize.round().toString(),
                          onChanged: (double v) =>
                              setModalState(() => fontSize = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Line height'),
                      Expanded(
                        child: Slider(
                          value: lineHeight,
                          min: 1.2,
                          max: 2.2,
                          divisions: 10,
                          label: lineHeight.toStringAsFixed(1),
                          onChanged: (double v) =>
                              setModalState(() => lineHeight = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('Margin'),
                      Expanded(
                        child: Slider(
                          value: margin,
                          min: 8,
                          max: 40,
                          divisions: 8,
                          label: margin.round().toString(),
                          onChanged: (double v) =>
                              setModalState(() => margin = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Theme', style: Theme.of(ctx).textTheme.titleMedium),
                  Wrap(
                    spacing: 8,
                    children: <String>['light', 'dark', 'sepia', 'high-contrast']
                        .map(
                          (String t) => ChoiceChip(
                            label: Text(t),
                            selected: theme == t,
                            onSelected: (_) => setModalState(() => theme = t),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text('Layout', style: Theme.of(ctx).textTheme.titleMedium),
                  Wrap(
                    spacing: 8,
                    children: <String>['scrolled', 'paginated']
                        .map(
                          (String l) => ChoiceChip(
                            label: Text(l),
                            selected: layout == l,
                            onSelected: (_) => setModalState(() => layout = l),
                          ),
                        )
                        .toList(),
                  ),
                  SwitchListTile(
                    title: const Text('Reduced motion'),
                    subtitle: const Text('Disable animations for e-ink / accessibility'),
                    value: reducedMotion,
                    onChanged: (bool v) =>
                        setModalState(() => reducedMotion = v),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ReaderSettings next = _settings.copyWith(
                          fontSize: fontSize,
                          lineHeight: lineHeight,
                          margin: margin,
                          theme: theme,
                          layout: layout,
                          reducedMotion: reducedMotion,
                        );
                        setState(() => _settings = next);
                        _paginated = next.layout == 'paginated';
                        await _applySettings();
                        await _saveSettings();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Bookmarks'),
          content: const Text(
            'Open this book from your library to manage bookmarks.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
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
      builder: (BuildContext ctx) => SafeArea(
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No bookmarks yet.'),
              )
            : ListView(
                shrinkWrap: true,
                children: list
                    .map(
                      (Bookmark bm) => ListTile(
                        title: Text(bm.label ?? 'Bookmark'),
                        subtitle: Text(bm.locator.cfi ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await widget.library!.deleteBookmark(bm.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
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
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Search in book'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Query'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _engine.search(_searchController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Search'),
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
          Semantics(
            label: 'Table of contents',
            child: IconButton(
              icon: const Icon(Icons.toc),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Contents',
            ),
          ),
          Semantics(
            label: _paginated
                ? 'Switch to vertical scrolling'
                : 'Switch to paginated layout',
            child: IconButton(
              icon: Icon(
                _paginated ? Icons.swap_vert : Icons.auto_stories_outlined,
              ),
              onPressed: () async {
                setState(() => _paginated = !_paginated);
                final String layout = _paginated ? 'paginated' : 'scrolled';
                _settings = _settings.copyWith(layout: layout);
                await _engine.setLayout(layout);
                await _saveSettings();
              },
              tooltip: _paginated ? 'Vertical scroll' : 'Paginated',
            ),
          ),
          Semantics(
            label: 'Bookmarks',
            child: IconButton(
              icon: const Icon(Icons.bookmarks),
              onPressed: _showBookmarks,
              tooltip: 'Bookmarks',
            ),
          ),
          Semantics(
            label: 'Typography and theme',
            child: IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _showSettings,
              tooltip: 'Typography and theme',
            ),
          ),
          Semantics(
            label: 'Search in book',
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showSearch,
              tooltip: 'Search',
            ),
          ),
          Semantics(
            label: 'Add bookmark',
            child: IconButton(
              icon: const Icon(Icons.bookmark_add),
              onPressed: () async {
                await _engine.addBookmark();
                final ReadingLocator? loc = _lastLocator;
                if (loc != null) {
                  await widget.onAddBookmark?.call(loc);
                }
              },
              tooltip: 'Bookmark',
            ),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _engine.controller),
          if (_loading)
            const ColoredBox(
              color: Color(0xFFFDFBF7),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_loadError != null)
            ColoredBox(
              color: const Color(0xFFFDFBF7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 12),
                      const Text('Could not open this book'),
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _loadError = null;
                          });
                          _openBook();
                        },
                        child: const Text('Retry'),
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
            if (_progress != null) Text('${(_progress! * 100).round()}%'),
            Semantics(
              label: 'Previous page',
              child: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _engine.goPrev,
                tooltip: 'Previous',
              ),
            ),
            Semantics(
              label: 'Next page',
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _engine.goNext,
                tooltip: 'Next',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
