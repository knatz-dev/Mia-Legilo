import 'package:benchmark_core/benchmark_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine_profiles.dart';
import '../engines/epub_rtl/epub_rtl_view.dart';
import '../engines/flutter_epub_viewer/epub_js_view.dart';
import '../engines/foliate_js/foliate_view.dart';
import '../widgets/bookmark_button.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.profile,
    required this.bookId,
    required this.bookTitle,
    required this.filePath,
    required this.bookmarks,
    required this.positions,
    this.initialLocation,
  });

  final EngineProfile profile;
  final String bookId;
  final String bookTitle;
  final String filePath;
  final BookmarkStore bookmarks;
  final PositionStore positions;
  final ReadingLocation? initialLocation;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  ReadingLocation? _location;
  late final ReadingLocation? _frozenInitial;
  String _chapterLabel = 'Chapter not reported yet';
  ReaderPreferences _preferences = const ReaderPreferences();
  var _showDiagnostics = false;
  double? _lastFrameMs;
  DateTime? _lastBoundary;
  int? _lastSpine;
  EpubRtlHandle? _rtl;
  EpubJsHandle? _epubJs;
  FoliateHandle? _foliate;

  @override
  void initState() {
    super.initState();
    _frozenInitial = widget.initialLocation ??
        widget.positions.read(widget.bookId, widget.profile.id);
    _location = _frozenInitial;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_showDiagnostics || timings.isEmpty) return;
    final ms = timings.last.totalSpan.inMicroseconds / 1000;
    if (!mounted) return;
    setState(() => _lastFrameMs = ms);
  }

  Future<void> _onLocation(ReadingLocation location) async {
    final previousSpine = _lastSpine;
    final spine = location.spineIndex;
    if (spine != null && previousSpine != null && spine != previousSpine) {
      _lastBoundary = DateTime.now();
    }
    _lastSpine = spine ?? _lastSpine;
    setState(() => _location = location);
    await widget.positions.save(widget.bookId, widget.profile.id, location);
  }

  Future<void> _toggleBookmark() async {
    final location = _location;
    if (location == null) return;
    final bookmark = Bookmark(
      id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      engineId: widget.profile.id,
      location: location,
      createdAt: DateTime.now().toUtc(),
      chapterLabel: _chapterLabel,
    );
    final pending = widget.bookmarks.toggle(bookmark);
    if (mounted) setState(() {});
    await pending;
  }

  Future<void> _openBookmarks() async {
    final selected = await Navigator.push<ReadingLocation>(
      context,
      MaterialPageRoute<ReadingLocation>(
        builder: (_) => BookmarksScreen(
          bookmarks: widget.bookmarks,
          bookId: widget.bookId,
          engineId: widget.profile.id,
        ),
      ),
    );
    if (selected == null) return;
    await _navigate(selected);
  }

  Future<void> _navigate(ReadingLocation location) async {
    final id = widget.profile.id;
    if (id == epubRtlProfile.id) {
      await _rtl?.navigate(location);
    } else if (id == epubJsProfile.id) {
      await _epubJs?.navigate(location);
    } else if (id == foliateProfile.id) {
      await _foliate?.navigate(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final bookmarked = location != null &&
        widget.bookmarks.matching(bookId: widget.bookId, location: location) != null;
    final progress = location?.progress;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookTitle, overflow: TextOverflow.ellipsis),
        actions: [
          BookmarkButton(
            active: bookmarked,
            enabled: location != null,
            onPressed: _toggleBookmark,
          ),
          IconButton(
            tooltip: 'Bookmarks',
            onPressed: _openBookmarks,
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: 'Typography',
            onPressed: _editPreferences,
            icon: const Icon(Icons.text_fields),
          ),
          IconButton(
            tooltip: 'Diagnostics',
            onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
            icon: Icon(_showDiagnostics ? Icons.bug_report : Icons.bug_report_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _statusBar(progress),
          Expanded(child: _engine()),
          if (_showDiagnostics) _diagnostics(location),
        ],
      ),
    );
  }

  Widget _statusBar(double? progress) {
    final progressText = progress == null
        ? 'Progress not reported'
        : 'Approximate progress ${(progress * 100).toStringAsFixed(1)}%';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(_chapterLabel, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(progressText, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }

  Widget _engine() {
    final initial = _frozenInitial;
    switch (widget.profile.id) {
      case 'epub_rtl':
        return EpubRtlView(
          filePath: widget.filePath,
          preferences: _preferences,
          initialLocation: initial,
          onLocation: _onLocation,
          onChapterLabel: (label) => setState(() => _chapterLabel = label),
          onHandle: (handle) => _rtl = handle,
        );
      case 'flutter_epub_viewer':
        return EpubJsView(
          filePath: widget.filePath,
          preferences: _preferences,
          initialLocation: initial,
          onLocation: _onLocation,
          onChapterLabel: (label) => setState(() => _chapterLabel = label),
          onHandle: (handle) => _epubJs = handle,
        );
      case 'foliate_js':
        return FoliateView(
          filePath: widget.filePath,
          preferences: _preferences,
          initialLocation: initial,
          onLocation: _onLocation,
          onChapterLabel: (label) => setState(() => _chapterLabel = label),
          onHandle: (handle) => _foliate = handle,
        );
      default:
        return const Center(child: Text('This engine is not hosted in this app.'));
    }
  }

  Widget _diagnostics(ReadingLocation? location) {
    final native = location?.nativeLocator;
    return Container(
      width: double.infinity,
      color: const Color(0xFF102027),
      padding: const EdgeInsets.all(12),
      child: Text(
        [
          'engine ${widget.profile.id} ${widget.profile.version}',
          'precision ${location?.precision.name ?? 'none'}',
          'spine ${location?.spineIndex ?? 'not exposed'}',
          'cfi ${location?.epubCfi ?? 'not exposed'}',
          'progress ${location?.progress ?? 'not exposed'} (approximate if present)',
          'native ${native ?? 'none'}',
          'last frame ${_lastFrameMs == null ? 'n/a' : '${_lastFrameMs!.toStringAsFixed(2)} ms'}',
          'last chapter-boundary change ${_lastBoundary?.toIso8601String() ?? 'none observed'}',
          'checkpoint stored in the position file after each reported location',
          'Frame timing is shown only while this overlay is open. It is not a benchmark sample.',
        ].join('\n'),
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
      ),
    );
  }

  Future<void> _editPreferences() async {
    final next = await showModalBottomSheet<ReaderPreferences>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PreferencesSheet(
        profile: widget.profile,
        initial: _preferences,
      ),
    );
    if (next == null || !mounted) return;
    setState(() => _preferences = next);
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.profile, required this.initial});

  final EngineProfile profile;
  final ReaderPreferences initial;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late ReaderPreferences _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('Typography', style: Theme.of(context).textTheme.titleMedium),
          Text(
            'Disabled rows are unsupported by this engine. The lab does not fake them.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text('Font size ${_value.fontSize.toStringAsFixed(0)}'),
          Slider(
            value: _value.fontSize,
            min: 14,
            max: 32,
            divisions: 18,
            label: _value.fontSize.toStringAsFixed(0),
            onChanged: widget.profile.supports('fontSize')
                ? (value) => setState(() => _value = _value.copyWith(fontSize: value))
                : null,
          ),
          Text('Line height ${_value.lineHeight.toStringAsFixed(2)}'),
          Slider(
            value: _value.lineHeight,
            min: 1.1,
            max: 2.2,
            divisions: 11,
            onChanged: widget.profile.supports('lineHeight')
                ? (value) => setState(() => _value = _value.copyWith(lineHeight: value))
                : null,
          ),
          DropdownButton<ReaderTheme>(
            value: _value.theme,
            onChanged: widget.profile.supports('theme')
                ? (theme) {
                    if (theme != null) setState(() => _value = _value.copyWith(theme: theme));
                  }
                : null,
            items: [
              for (final theme in ReaderTheme.values)
                DropdownMenuItem(value: theme, child: Text(theme.name)),
            ],
          ),
          SwitchListTile(
            title: const Text('Reduced motion'),
            subtitle: Text(
              widget.profile.supports('reducedMotion')
                  ? 'Requests the engine avoid extra transitions.'
                  : 'Unsupported by this engine.',
            ),
            value: _value.reducedMotion,
            onChanged: widget.profile.supports('reducedMotion')
                ? (value) => setState(() => _value = _value.copyWith(reducedMotion: value))
                : null,
          ),
          const Text('Unsupported in this engine'),
          Text(_unsupportedSummary()),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, _value),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  String _unsupportedSummary() {
    final names = [
      for (final entry in widget.profile.typography.entries)
        if (entry.value == FeatureSupport.unsupported) entry.key,
    ];
    if (names.isEmpty) return 'None of the catalogued fields are marked unsupported.';
    return names.join(', ');
  }
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({
    super.key,
    required this.bookmarks,
    required this.bookId,
    required this.engineId,
  });

  final BookmarkStore bookmarks;
  final String bookId;
  final String engineId;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  Widget build(BuildContext context) {
    final items = widget.bookmarks.forBook(widget.bookId, widget.engineId);
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: items.isEmpty
          ? const Center(child: Text('No bookmarks for this book and engine.'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final location = item.location;
                final where = location.epubCfi ??
                    'spine ${location.spineIndex ?? '-'} '
                        'element ${location.nativeLocator?['element'] ?? '-'}';
                return ListTile(
                  title: Text(item.chapterLabel ?? 'Bookmark'),
                  subtitle: Text(
                    '$where\n${item.createdAt.toLocal().toIso8601String()}\n'
                    'precision ${location.precision.name}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(context, location),
                  trailing: IconButton(
                    tooltip: 'Delete bookmark',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.bookmarks.delete(item.id);
                      if (mounted) setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
