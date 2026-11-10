import 'dart:io';

import 'package:benchmark_core/benchmark_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../engine_profiles.dart';
import 'reader_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.bookmarks,
    required this.positions,
    required this.manifest,
  });

  final BookmarkStore bookmarks;
  final PositionStore positions;
  final CorpusManifest manifest;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EngineProfile _engine = epubRtlProfile;
  CorpusBook? _book;
  String? _externalPath;
  String? _externalName;

  @override
  void initState() {
    super.initState();
    _book = widget.manifest.books.first;
  }

  Future<void> _open() async {
    final book = _book;
    final external = _externalPath;
    final String path;
    final String bookId;
    final String title;
    if (external != null) {
      path = external;
      bookId = external;
      title = _externalName ?? 'Selected EPUB';
    } else if (book != null) {
      path = await _materialise(book);
      bookId = book.id;
      title = book.title;
    } else {
      return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          profile: _engine,
          bookId: bookId,
          bookTitle: title,
          filePath: path,
          bookmarks: widget.bookmarks,
          positions: widget.positions,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<String> _materialise(CorpusBook book) async {
    final data = await rootBundle.load('assets/test_books/${book.filename}');
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/reader_lab/${book.filename}');
    await file.parent.create(recursive: true);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (!file.existsSync() || await file.length() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'EPUB', extensions: ['epub']),
      ],
    );
    if (file == null) return;
    setState(() {
      _externalPath = file.path;
      _externalName = file.name;
      _book = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hosted = engineProfiles.where((profile) => profile.hostedInThisApp);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mia Legilo Reader Lab'),
        actions: [
          IconButton(
            tooltip: 'Bookmarks',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BookmarksScreen(
                    bookmarks: widget.bookmarks,
                    bookId: _book?.id ?? _externalPath ?? '',
                    engineId: _engine.id,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: 'Evidence status',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const ResultsScreen()),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Engines in this app', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _engine.id,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _engine = profileById(value));
            },
            child: Column(
              children: [
                for (final profile in hosted)
                  RadioListTile<String>(
                    value: profile.id,
                    title: Text('${profile.name} ${profile.version}'),
                    subtitle: Text('${profile.license}. ${profile.launchNote}'),
                  ),
              ],
            ),
          ),
          const Divider(),
          Text(
            'flutter_readium ${readiumProfile.version} is a separate app. '
            '${readiumProfile.launchNote}',
          ),
          const SizedBox(height: 16),
          Text('Corpus', style: Theme.of(context).textTheme.titleMedium),
          Text(
            'License ${widget.manifest.license}. Generated fixtures, not commercial books.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          RadioGroup<String>(
            groupValue: _externalPath == null ? _book?.id : null,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _book = widget.manifest.books.firstWhere((book) => book.id == value);
                _externalPath = null;
                _externalName = null;
              });
            },
            child: Column(
              children: [
                for (final book in widget.manifest.books)
                  RadioListTile<String>(
                    value: book.id,
                    title: Text(book.title),
                    subtitle: Text(
                      '${book.filename} · ${book.spineItemCount} spine items · '
                      '${book.sizeBytes} bytes',
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: Text(_externalName == null ? 'Select another EPUB' : _externalName!),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _engine.hostedInThisApp ? _open : null,
            child: Text('Open in ${_engine.name}'),
          ),
          const SizedBox(height: 24),
          Text('Scroll architecture', style: Theme.of(context).textTheme.titleSmall),
          Text(_engine.scrollArchitecture),
          const SizedBox(height: 8),
          Text(_engine.locatorNotes),
        ],
      ),
    );
  }
}
