import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'data/book_store.dart';
import 'domain/book.dart';
import 'library/epub_inspector.dart';
import 'library/library_importer.dart';
import 'library/library_service.dart';
import 'library/resumable_downloader.dart';

void main() {
  runApp(const ProviderScope(child: MiaLegiloApp()));
}

class MiaLegiloApp extends StatelessWidget {
  const MiaLegiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mia Legilo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B4F3A)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  LibraryService? _library;
  List<Book> _books = <Book>[];
  String? _error;
  String? _message;
  bool _loading = true;
  bool _importing = false;
  bool _adopted = false;
  DownloadProgress? _progress;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _loadShelf();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _cancelToken?.cancel();
    _library?.close();
    super.dispose();
  }

  Future<void> _loadShelf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LibraryService library = _library ??= await LibraryService.open();
      if (!_adopted) {
        _adopted = true;
        final int adopted = await library.adoptDeviceShelf();
        if (adopted > 0) {
          // ignore: avoid_print
          print('LibraryService: adopted $adopted file(s) from the device shelf');
        }
      }
      final List<Book> books = await library.books();
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _open(Book book) async {
    final String? source = book.localAssetPath;
    if (source == null) {
      setState(() => _message = '"${book.title}" has no local file.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(source: source, title: book.title),
      ),
    );
    if (mounted) await _loadShelf();
  }

  Future<void> _importEpub() async {
    if (_importing) return;
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['epub'],
      allowMultiple: true,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    final LibraryService library = _library ??= await LibraryService.open();
    setState(() {
      _importing = true;
      _error = null;
      _message = null;
    });
    int imported = 0;
    int duplicates = 0;
    final List<String> failures = <String>[];
    for (final PlatformFile file in picked.files) {
      final String? path = file.path;
      if (path == null) {
        failures.add('${file.name}: the picker returned no readable path');
        continue;
      }
      try {
        final ImportResult result =
            await library.importFile(File(path), originalName: file.name);
        if (result.outcome == ImportOutcome.imported) {
          imported++;
        } else {
          duplicates++;
        }
      } on EpubValidationException catch (e) {
        failures.add('${file.name}: ${e.message}');
      } catch (e) {
        failures.add('${file.name}: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _importing = false;
      _message = <String>[
        if (imported > 0) 'Imported $imported book(s)',
        if (duplicates > 0) '$duplicates already in the library',
        if (failures.isNotEmpty) 'Skipped: ${failures.join('; ')}',
      ].join('. ');
      if (failures.isNotEmpty) _error = failures.join('\n');
    });
    await _loadShelf();
  }

  Future<void> _importUrl() async {
    if (_importing) return;
    _urlController.clear();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add book from URL'),
        content: TextField(
          controller: _urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'EPUB URL',
            hintText: 'https://example.org/book.epub',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    final String text = _urlController.text.trim();
    if (go != true || text.isEmpty) return;
    final Uri? uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = 'That does not look like a URL.');
      return;
    }

    final LibraryService library = _library ??= await LibraryService.open();
    final CancelToken token = CancelToken();
    setState(() {
      _importing = true;
      _cancelToken = token;
      _progress = const DownloadProgress(received: 0);
      _error = null;
      _message = null;
    });
    try {
      final ImportResult result = await library.importUrl(
        uri,
        cancelToken: token,
        onProgress: (DownloadProgress progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _message = result.message);
      await _loadShelf();
    } on DownloadCancelledException {
      if (!mounted) return;
      setState(() => _message = 'Download cancelled. Partial data was kept.');
    } on EpubValidationException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Not a valid EPUB: ${e.message}');
    } on DownloadException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _cancelToken = null;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mia Legilo'),
        actions: <Widget>[
          if (_importing && _cancelToken != null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Cancel download',
              onPressed: () => _cancelToken?.cancel(),
            ),
          Semantics(
            label: 'Import EPUB',
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Import EPUB',
              onPressed: _importing ? null : _importEpub,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload shelf',
            onPressed: _importing ? null : _loadShelf,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadShelf,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_loading) const LinearProgressIndicator(),
            if (_importing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Importing…'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: _progress?.fraction),
                  ],
                ),
              ),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            if (_message != null)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_message!),
                ),
              ),
            Row(
              children: <Widget>[
                const Expanded(child: Text('On this device')),
                Text(
                  '${_books.length} book(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_loading && _books.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No EPUB files yet. Tap + to import one, or copy books into:\n'
                  '${_library?.importer.booksDirectory.path ?? ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ..._books.map((Book book) => Card(
                  child: ListTile(
                    leading: _cover(book),
                    title: Text(book.title),
                    subtitle: Text(_subtitle(book)),
                    onTap: () => _open(book),
                  ),
                )),
            const Divider(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Add from URL'),
                onPressed: _importing ? null : _importUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Book book) {
    final String? cover = book.coverPath;
    if (cover == null) return const Icon(Icons.menu_book_outlined);
    final File file = File(cover);
    if (!file.existsSync()) return const Icon(Icons.menu_book_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        file,
        width: 40,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_outlined),
      ),
    );
  }

  String _subtitle(Book book) {
    final List<String> parts = <String>[];
    if (book.authors.isNotEmpty) parts.add(book.authors.join(', '));
    if (book.series != null) {
      parts.add(book.seriesIndex == null
          ? book.series!
          : '${book.series!} #${book.seriesIndex}');
    }
    if (parts.isEmpty) {
      final String? path = book.localAssetPath;
      if (path != null) parts.add(p.basename(path));
    }
    return parts.join(' · ');
  }
}
