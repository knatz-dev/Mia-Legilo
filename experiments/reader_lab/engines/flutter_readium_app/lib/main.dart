import 'dart:async';
import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:path_provider/path_provider.dart';

/// Isolated flutter_readium host.
///
/// Readium's EPUB `scroll` preference scrolls inside one resource. This app
/// turns that preference on and leaves page turns enabled, so a device run
/// can see whether the next spine item appears without a separate gesture.
/// A per-resource scroller does not satisfy R-001.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  final root = Directory('${directory.path}/readium_lab');
  await root.create(recursive: true);
  final bookmarks = BookmarkStore(File('${root.path}/bookmarks.json'));
  final positions = PositionStore(File('${root.path}/positions.json'));
  await bookmarks.load();
  await positions.load();
  final manifest = CorpusManifest.parse(
    await rootBundle.loadString('assets/test_books/corpus_manifest.json'),
  );
  runApp(ReadiumLabApp(bookmarks: bookmarks, positions: positions, manifest: manifest));
}

class ReadiumLabApp extends StatelessWidget {
  const ReadiumLabApp({
    super.key,
    required this.bookmarks,
    required this.positions,
    required this.manifest,
  });

  final BookmarkStore bookmarks;
  final PositionStore positions;
  final CorpusManifest manifest;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Readium Lab',
      home: Home(
        bookmarks: bookmarks,
        positions: positions,
        manifest: manifest,
      ),
    );
  }
}

class Home extends StatelessWidget {
  const Home({
    super.key,
    required this.bookmarks,
    required this.positions,
    required this.manifest,
  });

  final BookmarkStore bookmarks;
  final PositionStore positions;
  final CorpusManifest manifest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_readium 0.9.1')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Scroll mode is Readium EPUBPreferences.scroll. The plugin '
              'documents it as vertical scroll for reflowable content, and the '
              'Readium presentation model renders each spine item as its own '
              'scrollable document. This screen does not treat a forward '
              'page-turn as continuous scrolling.',
            ),
          ),
          for (final book in manifest.books)
            ListTile(
              title: Text(book.title),
              subtitle: Text('${book.spineItemCount} spine items'),
              onTap: () async {
                final path = await _materialise(book);
                if (!context.mounted) return;
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReadiumReaderScreen(
                      book: book,
                      filePath: path,
                      bookmarks: bookmarks,
                      positions: positions,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<String> _materialise(CorpusBook book) async {
    final data = await rootBundle.load('assets/test_books/${book.filename}');
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/readium_lab/${book.filename}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }
}

class ReadiumReaderScreen extends StatefulWidget {
  const ReadiumReaderScreen({
    super.key,
    required this.book,
    required this.filePath,
    required this.bookmarks,
    required this.positions,
  });

  final CorpusBook book;
  final String filePath;
  final BookmarkStore bookmarks;
  final PositionStore positions;

  @override
  State<ReadiumReaderScreen> createState() => _ReadiumReaderScreenState();
}

class _ReadiumReaderScreenState extends State<ReadiumReaderScreen> {
  final _readium = FlutterReadium();
  Publication? _publication;
  Locator? _locator;
  String? _error;
  StreamSubscription<Locator>? _subscription;
  final _preferences = const ReaderPreferences();

  @override
  void initState() {
    super.initState();
    _subscription = _readium.onTextLocatorChanged.listen((locator) {
      final location = _fromLocator(locator);
      widget.positions.save(widget.book.id, 'flutter_readium', location);
      if (mounted) setState(() => _locator = locator);
    });
    _open();
  }

  Future<void> _open() async {
    try {
      await _readium.setEPUBPreferences(_epubPreferences(_preferences));
      final publication = await _readium.openPublication(Uri.file(widget.filePath).toString());
      if (!mounted) {
        await _readium.closePublication();
        return;
      }
      setState(() => _publication = publication);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _readium.closePublication();
    super.dispose();
  }

  EPUBPreferences _epubPreferences(ReaderPreferences preferences) {
    final background = switch (preferences.theme) {
      ReaderTheme.light || ReaderTheme.eink => const Color(0xFFFFFFFF),
      ReaderTheme.dark => const Color(0xFF121212),
    };
    final foreground = preferences.theme == ReaderTheme.dark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF000000);
    return EPUBPreferences(
      scroll: true,
      publisherStyles: false,
      fontSize: preferences.fontSize / 18,
      fontFamily: preferences.fontFamily,
      lineHeight: preferences.lineHeight,
      paragraphSpacing: preferences.paragraphSpacingEm,
      pageMargins: preferences.marginPx / 20,
      backgroundColor: background,
      textColor: foreground,
      columnCount: EpubColumnCount.one,
    );
  }

  ReadingLocation _fromLocator(Locator locator) {
    final selector = locator.locations?.cssSelector;
    final quote = locator.text?.highlight;
    final anchor = '${locator.href}|${selector ?? ''}|${quote ?? ''}';
    final hasSemantic = (selector != null && selector.isNotEmpty) ||
        (quote != null && quote.isNotEmpty);
    return ReadingLocation(
      engineId: 'flutter_readium',
      precision: hasSemantic ? LocationPrecision.exact : LocationPrecision.approximate,
      progress: locator.locations?.totalProgression,
      nativeLocator: {
        'anchorId': anchor,
        'href': locator.href,
        'type': locator.type,
        'title': locator.title,
        'cssSelector': selector,
        'highlight': quote,
        'totalProgression': locator.locations?.totalProgression,
        'totalProgressionRole': 'approximate whole-publication fraction',
        'locator': locator.toJson(),
      },
    );
  }

  Locator? _savedLocator() {
    final stored = widget.positions.read(widget.book.id, 'flutter_readium');
    final raw = stored?.nativeLocator?['locator'];
    if (raw is! Map) return null;
    return Locator.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> _toggleBookmark() async {
    final locator = _locator;
    if (locator == null) return;
    final pending = widget.bookmarks.toggle(
      Bookmark(
        id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        bookId: widget.book.id,
        engineId: 'flutter_readium',
        location: _fromLocator(locator),
        createdAt: DateTime.now().toUtc(),
        chapterLabel: locator.title,
        excerpt: locator.text?.highlight,
      ),
    );
    if (mounted) setState(() {});
    await pending;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final publication = _publication;
    final location = _locator == null ? null : _fromLocator(_locator!);
    final bookmarked = location != null &&
        widget.bookmarks.matching(bookId: widget.book.id, location: location) != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Add bookmark',
            onPressed: location == null ? null : _toggleBookmark,
            icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: const Color(0xFFFFF3E0),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Observation: fling vertically. If the next chapter requires '
                'the forward control or a horizontal turn, AC-001 fails. '
                'totalProgression is approximate.',
              ),
            ),
          ),
          Expanded(
            child: error != null
                ? Center(child: Text(error))
                : publication == null
                    ? const Center(child: CircularProgressIndicator())
                    : ReadiumReaderWidget(
                        publication: publication,
                        initialLocator: _savedLocator(),
                        shouldShowControls: ValueNotifier<bool>(false),
                        disablePageTurnsWhileScrolling: false,
                        loadingWidget: const Center(child: CircularProgressIndicator()),
                      ),
          ),
        ],
      ),
    );
  }
}
