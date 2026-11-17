import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'core/design/fields.dart';
import 'core/design/theme.dart';
import 'core/design/tokens.dart';
import 'core/design/widgets.dart';
import 'domain/book.dart';
import 'domain/ids.dart';
import 'domain/locator.dart';
import 'domain/status.dart';
import 'features/cwng/cwng_browser_page.dart';
import 'features/library/book_details_page.dart';
import 'features/library/book_removal.dart';
import 'features/library/library_filters.dart';
import 'features/reader/reader_page.dart';
import 'features/settings/settings_model.dart';
import 'features/settings/settings_pages.dart';
import 'features/settings/settings_service.dart';
import 'library/epub_inspector.dart';
import 'library/library_importer.dart';
import 'library/library_query.dart';
import 'library/library_service.dart';
import 'library/resumable_downloader.dart';
import 'sync/sync_service.dart';

/// Opens the library once for the whole app and keeps it alive across tab
/// switches, so Settings and the library read and write the same Drift store.
final libraryProvider = FutureProvider<LibraryService>((ref) async {
  final LibraryService service = await LibraryService.open();
  ref.onDispose(service.close);
  return service;
});

/// The appearance currently in effect, so a settings save recolours the app.
final appearanceProvider = StateProvider<AppearanceSettings>(
  (ref) => const AppearanceSettings(),
);

void main() {
  runApp(const ProviderScope(child: MiaLegiloApp()));
}

class MiaLegiloApp extends ConsumerStatefulWidget {
  const MiaLegiloApp({super.key});

  @override
  ConsumerState<MiaLegiloApp> createState() => _MiaLegiloAppState();
}

class _MiaLegiloAppState extends ConsumerState<MiaLegiloApp> {
  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final LibraryService library = await ref.read(libraryProvider.future);
    final SettingsService settings = SettingsService(library);
    final AppearanceSettings value = await settings.appearance();
    if (mounted) ref.read(appearanceProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final AppearanceSettings appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: 'Mia Legilo',
      debugShowCheckedModeBanner: false,
      theme: buildMiaLegiloTheme(),
      darkTheme: buildMiaLegiloDarkTheme(),
      themeMode: switch (appearance.themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      home: const HomeShell(),
    );
  }
}

/// The app's navigation shell: a visible active location and a library that
/// owns its temporary controls.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  _AppTab _tab = _AppTab.library;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LibraryService> library = ref.watch(libraryProvider);
    if (library.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (library.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpace5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 40, color: kInkMuted),
                const SizedBox(height: kSpace3),
                const Text(
                  'The library could not be opened.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: kInk),
                ),
                const SizedBox(height: kSpace4),
                SketchButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(libraryProvider),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final LibraryService service = library.requireValue;
    final SettingsService settings = SettingsService(service);
    final AppearanceSettings appearance = ref.watch(appearanceProvider);
    final double roughness = appearance.sketchIntensity.roughness;
    return Scaffold(
      // IndexedStack keeps both tabs alive: switching must not dispose the
      // library (an in-progress import would abort, and the CWNG session and
      // its outbox would be dropped).
      body: IndexedStack(
        index: switch (_tab) {
          _AppTab.library => 0,
          _AppTab.settings => 1,
        },
        children: <Widget>[
          LibraryScreen(library: service),
          SettingsHost(
            service: settings,
            child: SettingsPage(settings: settings),
          ),
        ],
      ),
      bottomNavigationBar: _AppTabBar(
        current: _tab,
        roughness: roughness,
        onChanged: (_AppTab tab) => setState(() => _tab = tab),
      ),
    );
  }
}

enum _AppTab { library, settings }

class _AppTabBar extends StatelessWidget {
  const _AppTabBar({
    required this.current,
    required this.onChanged,
    required this.roughness,
  });

  final _AppTab current;
  final ValueChanged<_AppTab> onChanged;
  final double roughness;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: kPaperSurface,
          border: Border(top: BorderSide(color: kBorderFaint)),
        ),
        child: Row(
          children: <Widget>[
            for (final _AppTab tab in _AppTab.values)
              Expanded(
                child: _TabButton(
                  tab: tab,
                  selected: tab == current,
                  roughness: roughness,
                  onTap: () => onChanged(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.roughness,
  });

  final _AppTab tab;
  final bool selected;
  final VoidCallback onTap;
  final double roughness;

  String get _label => switch (tab) {
    _AppTab.library => 'Library',
    _AppTab.settings => 'Settings',
  };

  IconData get _icon => switch (tab) {
    _AppTab.library => Icons.menu_book_outlined,
    _AppTab.settings => Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? kAccent : kInkMuted;
    return Semantics(
      label: _label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTarget + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(_icon, size: 21, color: foreground),
              const SizedBox(height: 3),
              Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 28,
                child: selected
                    ? SketchNavUnderline(width: 28)
                    : const SizedBox(height: 5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The library screen. Its controls are temporary and stay here; saved
/// defaults live in Settings → Library.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.library});

  final LibraryService? library;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  LibraryService? _library;
  List<Book> _books = <Book>[];
  LibraryQuery _query = const LibraryQuery();
  String? _error;
  String? _message;
  bool _loading = true;
  bool _importing = false;
  bool _showAdvancedFilters = false;
  DownloadProgress? _progress;
  List<Map<String, dynamic>> _savedViews = <Map<String, dynamic>>[];
  CancelToken? _cancelToken;
  int _queryGeneration = 0;
  Future<void> _queryWrites = Future<void>.value();
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
        // Saved defaults from Settings → Library, then the last live query.
        final SettingsService settings = SettingsService(library);
        final LibraryDefaults defaults = await settings.libraryDefaults();
        LibraryQuery q = _query.copyWith(
          viewMode: defaults.viewMode,
          sort: defaults.sort,
          direction: defaults.direction,
          groupBy: defaults.groupBy,
          sourceFilter: defaults.sourceFilter,
          availabilityFilter: defaults.availabilityFilter,
          statuses: defaults.statuses
              .map((String name) => ReadingStatus.values.byName(name))
              .toSet(),
        );
        final raw = await library.store.readSetting('library.query');
        if (raw != null) {
          q = LibraryQuery.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        _query = q;
        _searchController
          ..removeListener(_onSearchChanged)
          ..text = q.search ?? ''
          ..addListener(_onSearchChanged);
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
      if (mounted) {
        setState(() => _error = 'Could not save library preferences: $error');
      }
    }
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..clear()
      ..addListener(_onSearchChanged);
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
      final SyncService? sync = library.syncService;
      if (sync != null) {
        await sync.enqueueStatusChange(
          bookId: book.id,
          status: status,
          providerInstanceId:
              book.remoteIdentity?.providerInstanceId ??
              ProviderInstanceId('cwng'),
          remoteBookId: book.remoteIdentity?.remoteBookId.value,
        );
        sync.sync().catchError((_) => const SyncResult());
      }
      if (mounted) await _loadShelf();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save status: $error');
    }
  }

  Future<void> _showBookActions(Book book) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SketchSheet(
        title: book.title,
        seedKey: 'book-actions-${book.id.value}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SketchNavRow(
              label: 'View details',
              icon: Icons.info_outline,
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            const Divider(height: 1),
            for (final ReadingStatus status in ReadingStatus.values)
              SketchNavRow(
                label: book.readingStatus == status
                    ? '${status.label} (current)'
                    : status.label,
                icon: book.readingStatus == status
                    ? Icons.check
                    : Icons.circle_outlined,
                onTap: () => Navigator.pop(ctx, status.name),
              ),
            const Divider(height: 1),
            if (book.localAssetPath != null)
              SketchNavRow(
                label: 'Remove download…',
                icon: Icons.download_done,
                onTap: () => Navigator.pop(ctx, 'download'),
              ),
            if (book.remoteIdentity == null)
              SketchNavRow(
                label: 'Remove local import…',
                icon: Icons.delete_outline,
                onTap: () => Navigator.pop(ctx, 'import'),
              ),
          ],
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
        setState(() {
          _error = 'The file is larger than the 512 MB import limit.';
        });
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
    final TextEditingController urlController = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SketchDialog(
        title: 'Add book from URL',
        seedKey: 'add-url',
        content: SketchTextField(
          label: 'EPUB URL',
          controller: urlController,
          hintText: 'https://example.org/book.epub',
          keyboardType: TextInputType.url,
          autofocus: true,
          seedKey: 'add-url-field',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          SketchButton(
            label: 'Download',
            onPressed: () => Navigator.pop(ctx, true),
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
      builder: (BuildContext ctx) => SketchDialog(
        title: 'Save current view',
        seedKey: 'save-view',
        content: SketchTextField(
          label: 'View name',
          controller: c,
          autofocus: true,
          seedKey: 'save-view-name',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          SketchButton(
            label: 'Save',
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
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
    _searchController
      ..removeListener(_onSearchChanged)
      ..text = next.search ?? ''
      ..addListener(_onSearchChanged);
    _updateQuery(next);
  }

  Future<void> _deleteSavedView(String name) async {
    _savedViews.removeWhere((Map<String, dynamic> v) => v['name'] == name);
    await _persistSavedViews();
    if (mounted) setState(() {});
  }

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

  String _groupLabel(LibraryGroupBy g) => switch (g) {
    LibraryGroupBy.none => 'None',
    LibraryGroupBy.author => 'Author',
    LibraryGroupBy.series => 'Series',
    LibraryGroupBy.status => 'Status',
    LibraryGroupBy.source => 'Source',
    LibraryGroupBy.availability => 'Availability',
  };

  @override
  Widget build(BuildContext context) {
    final AppearanceSettings appearance = ref.watch(appearanceProvider);
    final double roughness = appearance.sketchIntensity.roughness;
    final bool wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: <Widget>[
          if (_library?.syncService != null)
            SketchIconButton(
              icon: _library!.syncService!.isSyncing
                  ? Icons.sync
                  : Icons.sync_outlined,
              tooltip: 'Sync with CWNG',
              onPressed: _library!.syncService!.isSyncing
                  ? null
                  : () async {
                      final result = await _library!.syncService!.sync();
                      if (mounted) {
                        setState(() {
                          _message =
                              'Sync: ${result.committed} committed, '
                              '${result.failed} failed';
                        });
                        await _loadShelf();
                      }
                    },
            ),
          if (_importing && _cancelToken != null)
            SketchIconButton(
              icon: Icons.cancel_outlined,
              tooltip: 'Cancel download',
              onPressed: () => _cancelToken?.cancel(),
            ),
          SketchIconButton(
            icon: Icons.add,
            tooltip: 'Import EPUB',
            onPressed: _importing ? null : _importEpub,
          ),
          SketchIconButton(
            icon: Icons.refresh,
            tooltip: 'Reload library',
            onPressed: _importing ? null : _loadShelf,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadShelf,
        child: SketchPage(
          child: ListView(
            padding: EdgeInsets.all(wide ? kSpace5 : kSpace4),
            children: <Widget>[
              if (_loading) const LinearProgressIndicator(),
              if (_importing)
                Padding(
                  padding: const EdgeInsets.only(bottom: kSpace3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SketchLabel('Importing…'),
                      const SizedBox(height: kSpace2),
                      LinearProgressIndicator(value: _progress?.fraction),
                    ],
                  ),
                ),
              if (_error != null) ...<Widget>[
                SketchNotice(message: _error!, kind: SketchNoticeKind.error),
                const SizedBox(height: kSpace3),
              ],
              if (_message != null) ...<Widget>[
                SketchNotice(message: _message!),
                const SizedBox(height: kSpace3),
              ],
              SketchTextField(
                label: 'Search title, author, series…',
                controller: _searchController,
                prefixIcon: Icons.search,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () => _searchController.clear(),
                      ),
                seedKey: 'library-search',
              ),
              const SizedBox(height: kSpace3),
              // Status chips: the frequently used filter, always visible.
              Wrap(
                spacing: kSpace2,
                runSpacing: kSpace2,
                children: <Widget>[
                  SketchFilterChip(
                    label: 'All',
                    selected: _query.statuses.isEmpty,
                    onSelected: (_) => _updateQuery(
                      _query.copyWith(statuses: <ReadingStatus>{}),
                    ),
                    seedKey: 'status-all',
                  ),
                  for (final ReadingStatus s in ReadingStatus.values)
                    SketchFilterChip(
                      label: s.label,
                      selected: _query.statuses.contains(s),
                      onSelected: (bool v) => _updateQuery(
                        _query.copyWith(
                          statuses: v
                              ? {..._query.statuses, s}
                              : ({..._query.statuses}..remove(s)),
                        ),
                      ),
                      seedKey: 'status-${s.name}',
                    ),
                ],
              ),
              const SizedBox(height: kSpace3),
              // Compact toolbar: sort, view, and the advanced-filters toggle.
              SketchToolbar(
                children: <Widget>[
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
                  SketchIconButton(
                    icon: _query.viewMode == LibraryViewMode.grid
                        ? Icons.view_list
                        : Icons.grid_view,
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
                  SketchIconButton(
                    icon: Icons.filter_list,
                    tooltip: _showAdvancedFilters
                        ? 'Hide filters'
                        : 'Show filters',
                    selected: _showAdvancedFilters,
                    onPressed: () => setState(
                      () => _showAdvancedFilters = !_showAdvancedFilters,
                    ),
                  ),
                ],
              ),
              if (_showAdvancedFilters) ...<Widget>[
                const SizedBox(height: kSpace3),
                _AdvancedFilters(
                  query: _query,
                  savedViews: _savedViews,
                  onQuery: _updateQuery,
                  onApplySavedView: _applySavedView,
                  onSaveView: _saveCurrentView,
                  onDeleteSavedView: _deleteSavedView,
                  sourceLabel: _sourceLabel,
                  availLabel: _availLabel,
                  groupLabel: _groupLabel,
                ),
              ],
              const SizedBox(height: kSpace3),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_books.length} book${_books.length == 1 ? '' : 's'}'
                      '${_query.hasFilters ? ' in view' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                  if (_query.hasFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
                    ),
                  const SizedBox(width: kSpace2),
                  SketchButton(
                    label: 'Filters',
                    icon: Icons.tune,
                    seedKey: 'open-filters',
                    onPressed: _showFilters,
                  ),
                ],
              ),
              // Applied filters stay visible so the scope is always clear.
              if (_query.hasFilters) ...<Widget>[
                const SizedBox(height: kSpace2),
                Wrap(
                  spacing: kSpace2,
                  runSpacing: kSpace2,
                  children: <Widget>[
                    if ((_query.search ?? '').trim().isNotEmpty)
                      SketchBadge(
                        label: 'Search: ${_query.search}',
                        seedKey: 'applied-search',
                      ),
                    for (final ReadingStatus s in _query.statuses)
                      SketchBadge(label: s.label, seedKey: 'applied-${s.name}'),
                    if (_query.sourceFilter != LibrarySourceFilter.all)
                      SketchBadge(
                        label: _sourceLabel(_query.sourceFilter),
                        seedKey: 'applied-source',
                      ),
                    if (_query.availabilityFilter !=
                        LibraryAvailabilityFilter.all)
                      SketchBadge(
                        label: _availLabel(_query.availabilityFilter),
                        seedKey: 'applied-availability',
                      ),
                    if (_query.authors.isNotEmpty)
                      SketchBadge(
                        label: '${_query.authors.length} author(s)',
                        seedKey: 'applied-authors',
                      ),
                    if (_query.series.isNotEmpty)
                      SketchBadge(
                        label: '${_query.series.length} series',
                        seedKey: 'applied-series',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: kSpace3),
              if (!_loading && _books.isEmpty && _query.hasFilters)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: kSpace5),
                  child: Text(
                    'No books match these filters. Clear filters to see your '
                    'library.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: kInkMuted,
                    ),
                  ),
                ),
              if (!_loading && _books.isEmpty && !_query.hasFilters)
                _EmptyState(path: _library?.importer.booksDirectory.path ?? ''),
              if (_books.isNotEmpty)
                _GroupedBooks(
                  books: _books,
                  groupBy: _query.groupBy,
                  viewMode: _query.viewMode,
                  roughness: roughness,
                  onOpen: _open,
                  onLongPress: _showBookActions,
                ),
              const SizedBox(height: kSpace4),
              const SketchSectionHeading('Get books'),
              const SizedBox(height: kSpace2),
              const Text(
                'Add a book from your device, from a URL, or browse a connected '
                'CWNG library.',
                style: TextStyle(fontSize: 13, height: 1.45, color: kInkMuted),
              ),
              const SizedBox(height: kSpace3),
              Wrap(
                spacing: kSpace2,
                runSpacing: kSpace2,
                children: <Widget>[
                  SketchButton(
                    label: 'Browse CWNG',
                    icon: Icons.cloud_outlined,
                    seedKey: 'browse-cwng',
                    onPressed: _library == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CwngBrowserPage(
                                      library: _library!,
                                      settings: SettingsService(_library!),
                                    ),
                              ),
                            );
                          },
                  ),
                  SketchButton(
                    label: 'Add from URL',
                    icon: Icons.link,
                    seedKey: 'add-url',
                    onPressed: _importing ? null : _importUrl,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouping, source, availability and saved views, revealed on request.
class _AdvancedFilters extends StatelessWidget {
  const _AdvancedFilters({
    required this.query,
    required this.savedViews,
    required this.onQuery,
    required this.onApplySavedView,
    required this.onSaveView,
    required this.onDeleteSavedView,
    required this.sourceLabel,
    required this.availLabel,
    required this.groupLabel,
  });

  final LibraryQuery query;
  final List<Map<String, dynamic>> savedViews;
  final ValueChanged<LibraryQuery> onQuery;
  final ValueChanged<Map<String, dynamic>> onApplySavedView;
  final VoidCallback onSaveView;
  final ValueChanged<String> onDeleteSavedView;
  final String Function(LibrarySourceFilter) sourceLabel;
  final String Function(LibraryAvailabilityFilter) availLabel;
  final String Function(LibraryGroupBy) groupLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SketchLabel('GROUP BY'),
        const SizedBox(height: kSpace2),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: <Widget>[
            for (final LibraryGroupBy g in LibraryGroupBy.values)
              SketchFilterChip(
                label: groupLabel(g),
                selected: query.groupBy == g,
                onSelected: (_) => onQuery(query.copyWith(groupBy: g)),
                seedKey: 'group-${g.name}',
              ),
          ],
        ),
        const SizedBox(height: kSpace4),
        const SketchLabel('SOURCE'),
        const SizedBox(height: kSpace2),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: <Widget>[
            for (final LibrarySourceFilter f in LibrarySourceFilter.values)
              SketchFilterChip(
                label: sourceLabel(f),
                selected: query.sourceFilter == f,
                onSelected: (_) => onQuery(query.copyWith(sourceFilter: f)),
                seedKey: 'source-${f.name}',
              ),
          ],
        ),
        const SizedBox(height: kSpace4),
        const SketchLabel('FILES'),
        const SizedBox(height: kSpace2),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: <Widget>[
            for (final LibraryAvailabilityFilter f
                in LibraryAvailabilityFilter.values)
              SketchFilterChip(
                label: availLabel(f),
                selected: query.availabilityFilter == f,
                onSelected: (_) =>
                    onQuery(query.copyWith(availabilityFilter: f)),
                seedKey: 'availability-${f.name}',
              ),
          ],
        ),
        const SizedBox(height: kSpace4),
        const SketchLabel('SAVED VIEWS'),
        const SizedBox(height: kSpace2),
        if (savedViews.isEmpty)
          const Text(
            'No saved views yet. Set filters, then save the view.',
            style: TextStyle(fontSize: 13, height: 1.45, color: kInkMuted),
          )
        else
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: <Widget>[
              for (final Map<String, dynamic> view in savedViews)
                SketchFilterChip(
                  label: view['name'] as String,
                  selected: false,
                  onSelected: (_) => onApplySavedView(view),
                  seedKey: 'saved-view-${view['name']}',
                ),
            ],
          ),
        const SizedBox(height: kSpace2),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: <Widget>[
            SketchButton(
              label: 'Save current view',
              icon: Icons.save_outlined,
              seedKey: 'save-view',
              onPressed: onSaveView,
            ),
            if (savedViews.isNotEmpty)
              SketchButton(
                label: 'Delete a view',
                icon: Icons.delete_outline,
                seedKey: 'delete-view',
                onPressed: () async {
                  final String? name = await showModalBottomSheet<String>(
                    context: context,
                    builder: (BuildContext ctx) => SketchSheet(
                      title: 'Delete a saved view',
                      seedKey: 'delete-view-sheet',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final Map<String, dynamic> view in savedViews)
                            SketchNavRow(
                              label: view['name'] as String,
                              icon: Icons.bookmark_remove_outlined,
                              onTap: () =>
                                  Navigator.pop(ctx, view['name'] as String),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (name != null) onDeleteSavedView(name);
                },
              ),
          ],
        ),
      ],
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
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTarget),
            padding: const EdgeInsets.symmetric(horizontal: kSpace2),
            alignment: Alignment.center,
            child: Text(
              'Sort: ${_label(value)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
            ),
          ),
        ),
        SketchIconButton(
          icon: direction == LibrarySortDirection.ascending
              ? Icons.arrow_upward
              : Icons.arrow_downward,
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
      padding: const EdgeInsets.symmetric(vertical: kSpace6),
      child: Column(
        children: <Widget>[
          const Icon(Icons.menu_book_outlined, size: 44, color: kInkMuted),
          const SizedBox(height: kSpace3),
          const Text(
            'No EPUB files yet.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          const SizedBox(height: kSpace2),
          Text(
            'Tap + to import one, or copy books into:\n$path',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: kInkMuted,
            ),
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
    required this.roughness,
  });

  final List<Book> books;
  final LibraryGroupBy groupBy;
  final LibraryViewMode viewMode;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onLongPress;
  final double roughness;

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
                roughness: roughness,
                onOpen: onOpen,
                onLongPress: onLongPress,
              )
            : _BookList(
                books: section.value,
                roughness: roughness,
                onOpen: onOpen,
                onLongPress: onLongPress,
              );
        if (groupBy == LibraryGroupBy.none) return content;
        return _SketchGroup(
          title: '${section.key} (${section.value.length})',
          roughness: roughness,
          children: content,
        );
      }).toList(),
    );
  }
}

/// A collapsible group heading with the app's spacing and type, replacing the
/// Material expansion tile's filled header.
class _SketchGroup extends StatelessWidget {
  const _SketchGroup({
    required this.title,
    required this.children,
    required this.roughness,
  });

  final String title;
  final Widget children;
  final double roughness;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: kSpace3),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        ),
        children: <Widget>[children],
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({
    required this.books,
    required this.onOpen,
    required this.onLongPress,
    required this.roughness,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onLongPress;
  final double roughness;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: books
          .map(
            (Book book) => Padding(
              padding: const EdgeInsets.only(bottom: kSpace2),
              child: SketchSurface(
                seedKey: 'book-${book.id.value}',
                roughness: roughness,
                padding: const EdgeInsets.all(kSpace2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _cover(book),
                    const SizedBox(width: kSpace3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(book),
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: kInkMuted,
                            ),
                          ),
                          if (book.progressPercentage != null) ...<Widget>[
                            const SizedBox(height: kSpace1),
                            Text(
                              '${(book.progressPercentage! * 100).round()}% read',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SketchIconButton(
                      icon: Icons.more_vert,
                      tooltip: 'Book actions',
                      onPressed: () => onLongPress(book),
                    ),
                  ],
                ),
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
    required this.roughness,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onLongPress;
  final double roughness;

  @override
  Widget build(BuildContext context) {
    final int columns = MediaQuery.of(context).size.width >= 720 ? 4 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.62,
        crossAxisSpacing: kSpace2,
        mainAxisSpacing: kSpace2,
      ),
      itemCount: books.length,
      itemBuilder: (BuildContext ctx, int i) {
        final Book book = books[i];
        return SketchSurface(
          seedKey: 'book-grid-${book.id.value}',
          roughness: roughness,
          padding: const EdgeInsets.all(kSpace2),
          child: InkWell(
            onTap: () => onOpen(book),
            onLongPress: () => onLongPress(book),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _cover(book, fill: true)),
                const SizedBox(height: kSpace2),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  book.authors.isEmpty
                      ? 'Unknown author'
                      : book.authors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kInkMuted),
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
  final Widget placeholder = Icon(
    Icons.menu_book_outlined,
    size: fill ? 40 : 28,
    color: kInkMuted,
  );
  if (cover == null) return fill ? Center(child: placeholder) : placeholder;
  final File file = File(cover);
  if (!file.existsSync()) {
    return fill ? Center(child: placeholder) : placeholder;
  }
  return Image.file(
    file,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => placeholder,
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
