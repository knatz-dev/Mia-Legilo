import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../reader_engines/foliate/foliate_engine.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, this.source, this.title});

  /// Local file path or remote URL of the EPUB to display.
  final String? source;
  final String? title;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final FoliateEngine _engine;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _loadError;
  bool _paginated = false;

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
      await _engine.load(source);
      await _engine.bookOpened;
      if (!mounted) return;
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
    _searchController.dispose();
    _engine.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: Text(widget.title ?? 'Reader', overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          Semantics(
            label: _paginated ? 'Switch to vertical scrolling' : 'Switch to paginated layout',
            child: IconButton(
              icon: Icon(_paginated ? Icons.swap_vert : Icons.auto_stories_outlined),
              onPressed: () {
                setState(() => _paginated = !_paginated);
                _engine.setLayout(_paginated ? 'paginated' : 'scrolled');
              },
              tooltip: _paginated ? 'Vertical scroll' : 'Paginated',
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
              onPressed: _engine.addBookmark,
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
