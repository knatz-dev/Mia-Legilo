import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'domain/book.dart';
import 'domain/locator.dart';
import 'domain/status.dart';
import 'features/library/book_details_page.dart';
import 'features/library/book_removal.dart';
import 'features/library/library_filters.dart';
import 'features/reader/reader_page.dart';
import 'library/epub_inspector.dart';
import 'library/library_importer.dart';
import 'library/library_query.dart';
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
  const HomeScreen({super.key, this.library});

  final LibraryService? library;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  LibraryService? _library;
  List<Book> _books = <Book>[];
  LibraryQuery _query = const LibraryQuery();
  String? _error;
  String? _message;
  bool _loading = true;
  bool _importing = false;
  DownloadProgress? _progress;
  List<Map<String, dynamic>> _savedViews = <Map<String, dynamic>>[];
  CancelToken? _cancelToken;
  int _queryGeneration = 0;
  Future<void> _queryWrites = Future<void>.value();
  bool _autoStartReading = true;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadShelf();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cancelToken?.cancel();
    if (widget.library == null) _library?.close();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _updateQuery(
        _query.copyWith(
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          clearSearch: _searchController.text.trim().isEmpty,
        ),
      );
    });
  }

  Future<void> _loadShelf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LibraryService library = _library ??=
          widget.library ?? await LibraryService.open();
      if (!_prefsLoaded) {
        _prefsLoaded = true;
        final String? view = await library.store.readSetting(
          'library.viewMode',
        );
        final String? sort = await library.store.readSetting('library.sort');
        final String? dir = await library.store.readSetting('library.sortDir');
        LibraryQuery q = _query;
        if (view != null) {
          q = q.copyWith(
            viewMode: view == 'grid'
                ? LibraryViewMode.grid
                : LibraryViewMode.list,
          );
        }
        if (sort != null) {
          final LibrarySortKey? key = _sortKeyByName(sort);
          if (key != null) q = q.copyWith(sort: key);
        }
        if (dir != null) {
          q = q.copyWith(
            direction: dir == 'desc'
                ? LibrarySortDirection.descending
                : LibrarySortDirection.ascending,
          );
        }
        final raw = await library.store.readSetting('library.query');
        if (raw != null)
          q = LibraryQuery.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _query = q;
        _searchController.removeListener(_onSearchChanged);
        _searchController.text = q.search ?? '';
        _searchController.addListener(_onSearchChanged);
        _autoStartReading = await library.autoStartEnabled();
      }
      await _loadSavedViews();
      final int adopted = widget.library == null
          ? await library.adoptDeviceShelf()
          : 0;
      if (adopted > 0) {
        // ignore: avoid_print
        print('LibraryService: adopted $adopted file(s) from the device shelf');
      }
      final List<Book> books = await library.store.query(_query);
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

  Future<void> _updateQuery(LibraryQuery next) async {
    final library = _library;
    setState(() => _query = next);
    try {
      if (library != null) {
        _queryWrites = _queryWrites
            .catchError((Object _) {})
            .then(
              (_) => library.store.writeSetting(
                'library.query',
                jsonEncode(next.toJson()),
              ),
            );
        await _queryWrites;
      }
      if (mounted) await _runQuery();
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not save library preferences: $error');
    }
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchChanged);
    _updateQuery(_query.clearFilters());
  }

  Future<void> _showFilters() async {
    final library = _library;
    if (library == null) return;
    final books = await library.books();
    if (!mounted) return;
    final next = await showDialog<LibraryQuery>(
      context: context,
      builder: (_) => LibraryFilters(query: _query, books: books),
    );
    if (next != null && mounted) await _updateQuery(next);
  }

  Future<void> _runQuery() async {
    final LibraryService? library = _library;
    if (library == null) return;
    final generation = ++_queryGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Book> books = await library.store.query(_query);
      if (!mounted || generation != _queryGeneration) return;
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
        builder: (_) => ReaderPage(
          source: source,
          title: book.title,
          initialStatus: book.readingStatus,
          initialStatusManual: book.readingStatusManual,
          initialLocator: book.locator,
          bookId: book.id.value,
          onFinished: () => _setStatus(book, ReadingStatus.completed),
          onAddBookmark: (ReadingLocator locator) =>
              _library!.addBookmark(book.id, locator),
          library: _library,
        ),
      ),
    );
    if (mounted) await _loadShelf();
  }

  Future<void> _setStatus(Book book, ReadingStatus status) async {
    final library = _library;
    if (library == null) return;
    try {
      await library.setStatus(book.id, status);
      if (mounted) await _loadShelf();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save status: $error');
    }
  }

  Future<void> _showBookActions(Book book) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View details'),
                onTap: () => Navigator.pop(ctx, 'details'),
              ),
              const Divider(),
              for (final status in ReadingStatus.values)
                ListTile(
                  leading: Icon(
                    book.readingStatus == status
                        ? Icons.check
                        : Icons.circle_outlined,
                  ),
                  title: Text(status.label),
                  onTap: () => Navigator.pop(ctx, status.name),
                ),
              const Divider(),
              if (book.localAssetPath != null)
                ListTile(
                  leading: const Icon(Icons.download_done),
                  title: const Text('Remove download…'),
                  onTap: () => Navigator.pop(ctx, 'download'),
                ),
              if (book.remoteIdentity == null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove local import…'),
                  onTap: () => Navigator.pop(ctx, 'import'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == 'details') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookDetailsPage(book: book, library: _library!),
        ),
      );
      if (mounted) await _loadShelf();
    } else if (chosen == 'download' || chosen == 'import') {
      if (await confirmBookRemoval(
        context,
        _library!,
        book,
        downloadOnly: chosen == 'download',
      )) {
        if (mounted) await _loadShelf();
      }
    } else {
      await _setStatus(book, ReadingStatus.values.byName(chosen));
    }
  }

  Future<void> _importEpub() async {
    if (_importing) return;
    const XTypeGroup epubGroup = XTypeGroup(
      label: 'EPUB',
      extensions: <String>['epub'],
      mimeTypes: <String>['application/epub+zip'],
    );
    final XFile? picked = await openFile(
      acceptedTypeGroups: <XTypeGroup>[epubGroup],
    );
    if (picked == null) return;

    final LibraryService library = _library ??= await LibraryService.open();
    setState(() {
      _importing = true;
      _error = null;
      _message = null;
    });
    try {
      final int length = await picked.length();
      if (length > LibraryImporter.maxImportBytes) {
        setState(
          () => _error = 'The file is larger than the 512 MB import limit.',
        );
      } else {
        final ImportResult result = await library.importBytes(
          await picked.readAsBytes(),
          name: picked.name,
        );
        if (!mounted) return;
        setState(() => _message = result.message);
        await _loadShelf();
      }
    } on EpubValidationException catch (e) {
      if (mounted) setState(() => _error = 'Not a valid EPUB: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importUrl() async {
    if (_importing) return;
    _searchController.clear();
    // keep search controller separate; use a local controller for URL
    final TextEditingController urlController = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add book from URL'),
        content: TextField(
          controller: urlController,
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
    final String text = urlController.text.trim();
    urlController.dispose();
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

  Future<void> _loadSavedViews() async {
    final LibraryService? library = _library;
    if (library == null) return;
    try {
      final String? raw = await library.store.readSetting('library.savedViews');
      if (raw == null || raw.isEmpty) {
        _savedViews = <Map<String, dynamic>>[];
        return;
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        _savedViews = decoded
            .whereType<Map>()
            .map((Map m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      _savedViews = <Map<String, dynamic>>[];
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistSavedViews() async {
    final LibraryService? library = _library;
    if (library == null) return;
    await library.store.writeSetting(
      'library.savedViews',
      jsonEncode(_savedViews),
    );
  }

  Future<void> _saveCurrentView() async {
    final TextEditingController c = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Save current view'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'View name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    _savedViews.removeWhere((Map<String, dynamic> v) => v['name'] == name);
    _savedViews.add(<String, dynamic>{'name': name, ..._query.toJson()});
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  void _applySavedView(Map<String, dynamic> value) {
    final next = LibraryQuery.fromJson(value);
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.text = next.search ?? '';
    _searchController.addListener(_onSearchChanged);
    _updateQuery(next);
  }

  Future<void> _deleteSavedView(String name) async {
    _savedViews.removeWhere((Map<String, dynamic> v) => v['name'] == name);
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

  String _groupLabel(LibraryGroupBy g) => switch (g) {
    LibraryGroupBy.none => 'None',
    LibraryGroupBy.author => 'Author',
    LibraryGroupBy.series => 'Series',
    LibraryGroupBy.status => 'Status',
    LibraryGroupBy.source => 'Source',
    LibraryGroupBy.availability => 'Availability',
  };

  String _sourceLabel(LibrarySourceFilter f) => switch (f) {
    LibrarySourceFilter.all => 'All',
    LibrarySourceFilter.local => 'Local',
    LibrarySourceFilter.remote => 'Remote',
  };

  String _availLabel(LibraryAvailabilityFilter f) => switch (f) {
    LibraryAvailabilityFilter.all => 'All',
    LibraryAvailabilityFilter.available => 'Available',
    LibraryAvailabilityFilter.missing => 'Missing',
  };

  LibrarySortKey? _sortKeyByName(String name) {
    for (final LibrarySortKey k in LibrarySortKey.values) {
      if (k.name == name) return k;
    }
    return null;
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
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: Text(
                    'Filters (${_query.authors.length + _query.series.length + _query.shelfIds.length})',
                  ),
                  onPressed: _showFilters,
                ),
                if (_query.hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            SwitchListTile(
              title: const Text('Automatically mark as Reading'),
              subtitle: const Text(
                'On reading activity; manual statuses always take precedence.',
              ),
              value: _autoStartReading,
              onChanged: (value) async {
                try {
                  await _library?.store.writeSetting(
                    'library.autoStartReading',
                    value.toString(),
                  );
                  if (mounted) setState(() => _autoStartReading = value);
                } catch (error) {
                  if (mounted)
                    setState(
                      () => _error = 'Could not save preference: $error',
                    );
                }
              },
            ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search title, author, series…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _query.statuses.isEmpty,
                    onSelected: (_) => _updateQuery(
                      _query.copyWith(statuses: <ReadingStatus>{}),
                    ),
                  ),
                  for (final ReadingStatus s in ReadingStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(s.label),
                        selected: _query.statuses.contains(s),
                        onSelected: (bool v) => _updateQuery(
                          _query.copyWith(
                            statuses: v
                                ? {..._query.statuses, s}
                                : ({..._query.statuses}..remove(s)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButton<LibraryGroupBy>(
                    value: _query.groupBy,
                    isExpanded: true,
                    items: <DropdownMenuItem<LibraryGroupBy>>[
                      for (final LibraryGroupBy g in LibraryGroupBy.values)
                        DropdownMenuItem<LibraryGroupBy>(
                          value: g,
                          child: Text('Group: ${_groupLabel(g)}'),
                        ),
                    ],
                    onChanged: (LibraryGroupBy? g) {
                      if (g != null) _updateQuery(_query.copyWith(groupBy: g));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<LibrarySourceFilter>(
                    value: _query.sourceFilter,
                    isExpanded: true,
                    items: <DropdownMenuItem<LibrarySourceFilter>>[
                      for (final LibrarySourceFilter f
                          in LibrarySourceFilter.values)
                        DropdownMenuItem<LibrarySourceFilter>(
                          value: f,
                          child: Text('Source: ${_sourceLabel(f)}'),
                        ),
                    ],
                    onChanged: (LibrarySourceFilter? f) {
                      if (f != null)
                        _updateQuery(_query.copyWith(sourceFilter: f));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<LibraryAvailabilityFilter>(
                    value: _query.availabilityFilter,
                    isExpanded: true,
                    items: <DropdownMenuItem<LibraryAvailabilityFilter>>[
                      for (final LibraryAvailabilityFilter f
                          in LibraryAvailabilityFilter.values)
                        DropdownMenuItem<LibraryAvailabilityFilter>(
                          value: f,
                          child: Text('Files: ${_availLabel(f)}'),
                        ),
                    ],
                    onChanged: (LibraryAvailabilityFilter? f) {
                      if (f != null)
                        _updateQuery(_query.copyWith(availabilityFilter: f));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButton<String>(
                    hint: const Text('Saved views'),
                    value: null,
                    isExpanded: true,
                    items: _savedViews
                        .map(
                          (Map<String, dynamic> v) => DropdownMenuItem<String>(
                            value: v['name'] as String,
                            child: Text(v['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (String? name) {
                      if (name == null) return;
                      final Map<String, dynamic>? v = _savedViews
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (Map<String, dynamic>? e) => e?['name'] == name,
                            orElse: () => null,
                          );
                      if (v != null) _applySavedView(v);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: 'Save current view',
                  onPressed: _saveCurrentView,
                ),
                if (_savedViews.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'Delete a saved view',
                    icon: const Icon(Icons.delete_outline),
                    onSelected: _deleteSavedView,
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                      for (final Map<String, dynamic> v in _savedViews)
                        PopupMenuItem<String>(
                          value: v['name'] as String,
                          child: Text(v['name'] as String),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Library · ${_books.length} book(s)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _SortMenu(
                  value: _query.sort,
                  direction: _query.direction,
                  onChanged: (LibrarySortKey key) =>
                      _updateQuery(_query.copyWith(sort: key)),
                  onToggleDirection: () => _updateQuery(
                    _query.copyWith(
                      direction:
                          _query.direction == LibrarySortDirection.ascending
                          ? LibrarySortDirection.descending
                          : LibrarySortDirection.ascending,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _query.viewMode == LibraryViewMode.grid
                        ? Icons.view_list
                        : Icons.grid_view,
                  ),
                  tooltip: _query.viewMode == LibraryViewMode.grid
                      ? 'Switch to list'
                      : 'Switch to grid',
                  onPressed: () => _updateQuery(
                    _query.copyWith(
                      viewMode: _query.viewMode == LibraryViewMode.grid
                          ? LibraryViewMode.list
                          : LibraryViewMode.grid,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_loading && _books.isEmpty && _query.hasFilters)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No books match these filters. Clear filters to see your library.',
                ),
              ),
            if (!_loading && _books.isEmpty && !_query.hasFilters)
              _EmptyState(path: _library?.importer.booksDirectory.path ?? ''),
            if (_books.isNotEmpty)
              _GroupedBooks(
                books: _books,
                groupBy: _query.groupBy,
                viewMode: _query.viewMode,
                onOpen: _open,
                onLongPress: _showBookActions,
              ),
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
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.value,
    required this.direction,
    required this.onChanged,
    required this.onToggleDirection,
  });

  final LibrarySortKey value;
  final LibrarySortDirection direction;
  final ValueChanged<LibrarySortKey> onChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PopupMenuButton<LibrarySortKey>(
          initialValue: value,
          tooltip: 'Sort by',
          onSelected: onChanged,
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<LibrarySortKey>>[
            for (final LibrarySortKey k in LibrarySortKey.values)
              PopupMenuItem<LibrarySortKey>(value: k, child: Text(_label(k))),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _label(value),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            direction == LibrarySortDirection.ascending
                ? Icons.arrow_upward
                : Icons.arrow_downward,
          ),
          tooltip: 'Toggle sort direction',
          onPressed: onToggleDirection,
        ),
      ],
    );
  }

  String _label(LibrarySortKey key) => switch (key) {
    LibrarySortKey.title => 'Title',
    LibrarySortKey.author => 'Author',
    LibrarySortKey.added => 'Added',
    LibrarySortKey.lastRead => 'Last read',
    LibrarySortKey.series => 'Series',
    LibrarySortKey.progress => 'Progress',
    LibrarySortKey.status => 'Status',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          const Icon(Icons.menu_book_outlined, size: 48),
          const SizedBox(height: 8),
          Text(
            'No EPUB files yet.\nTap + to import one, or copy books into:\n$path',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GroupedBooks extends StatelessWidget {
  const _GroupedBooks({
    required this.books,
    required this.groupBy,
    required this.viewMode,
    required this.onOpen,
    required this.onLongPress,
  });

  final List<Book> books;
  final LibraryGroupBy groupBy;
  final LibraryViewMode viewMode;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onLongPress;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, List<Book>>> sections = groupBooks(
      books,
      groupBy,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((MapEntry<String, List<Book>> section) {
        final content = viewMode == LibraryViewMode.grid
            ? _BookGrid(
                books: section.value,
                onOpen: onOpen,
                onLongPress: onLongPress,
              )
            : _BookList(
                books: section.value,
                onOpen: onOpen,
                onLongPress: onLongPress,
              );
        if (groupBy == LibraryGroupBy.none) return content;
        return ExpansionTile(
          key: PageStorageKey('${groupBy.name}:${section.key}'),
          initiallyExpanded: true,
          title: Text('${section.key} (${section.value.length})'),
          children: [content],
        );
      }).toList(),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({
    required this.books,
    required this.onOpen,
    required this.onLongPress,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: books
          .map(
            (Book book) => Card(
              child: ListTile(
                leading: _cover(book),
                title: Text(book.title),
                subtitle: Text(_subtitle(book)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (book.progressPercentage != null)
                      Text('${(book.progressPercentage! * 100).round()}%'),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Book actions',
                      onPressed: () => onLongPress(book),
                    ),
                  ],
                ),
                onTap: () => onOpen(book),
                onLongPress: () => onLongPress(book),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({
    required this.books,
    required this.onOpen,
    required this.onLongPress,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onLongPress;

  @override
  Widget build(BuildContext context) {
    final int columns = MediaQuery.of(context).size.width >= 720 ? 4 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.62,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (BuildContext ctx, int i) {
        final Book book = books[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(book),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _cover(book, fill: true)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.authors.isEmpty
                            ? 'Unknown author'
                            : book.authors.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.more_vert, size: 18),
                          tooltip: 'Book actions',
                          onPressed: () => onLongPress(book),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _cover(Book book, {bool fill = false}) {
  final String? cover = book.coverPath;
  if (cover == null) {
    final Widget icon = Icon(Icons.menu_book_outlined, size: fill ? 48 : null);
    return fill ? Center(child: icon) : icon;
  }
  final File file = File(cover);
  if (!file.existsSync()) {
    final Widget icon = Icon(Icons.menu_book_outlined, size: fill ? 48 : null);
    return fill ? Center(child: icon) : icon;
  }
  return Image.file(
    file,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) =>
        Icon(Icons.menu_book_outlined, size: fill ? 48 : null),
  );
}

String _subtitle(Book book) {
  final List<String> parts = <String>[];
  if (book.authors.isNotEmpty) parts.add(book.authors.join(', '));
  if (book.series != null) {
    parts.add(
      book.seriesIndex == null
          ? book.series!
          : '${book.series!} #${book.seriesIndex}',
    );
  }
  if (parts.isEmpty) {
    final String? path = book.localAssetPath;
    if (path != null) parts.add(p.basename(path));
  }
  return parts.join(' · ');
}
