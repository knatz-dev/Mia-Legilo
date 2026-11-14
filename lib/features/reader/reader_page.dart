import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../reader_engines/foliate/foliate_engine.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, this.source});

  final String? source;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final FoliateEngine _engine;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _engine = FoliateEngine();
    _engine.initialize().then((_) {
      if (widget.source != null) {
        _engine.load(widget.source!);
      }
    });
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
      builder: (ctx) => AlertDialog(
        title: const Text('Search in book'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Query'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
        title: const Text('Reader'),
        actions: <Widget>[
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
      body: WebViewWidget(controller: _engine.controller),
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
