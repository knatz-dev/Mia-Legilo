import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/fields.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../domain/annotation.dart';
import '../../domain/book.dart';
import '../../domain/locator.dart';
import '../../domain/status.dart';
import '../../library/epub_inspector.dart';
import '../../library/library_service.dart';
import '../../sync/conflict_store.dart';
import '../reader/reader_page.dart';
import '../settings/settings_pages.dart';
import '../settings/settings_service.dart';
import 'book_removal.dart';

/// Book details: metadata, reading state, bookmarks and file information.
///
/// Feature-specific configuration (reader defaults) is reachable from here
/// and lives in Settings → Reader.
class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({
    super.key,
    required this.book,
    required this.library,
    this.onOpen,
    this.onChanged,
  });

  final Book book;
  final LibraryService library;
  final VoidCallback? onOpen;
  final VoidCallback? onChanged;

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  late Book _book;
  List<Bookmark> _bookmarks = <Bookmark>[];
  List<BookConflict> _conflicts = <BookConflict>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _ensureCover();
    _loadBookmarks();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    final ConflictStore? cs = widget.library.conflicts;
    if (cs == null) return;
    final List<BookConflict> list = await cs.unresolvedFor(_book.id);
    if (mounted) setState(() => _conflicts = list);
  }

  Future<void> _loadBookmarks() async {
    final List<Bookmark> list = await widget.library.bookmarksFor(_book.id);
    if (mounted) setState(() => _bookmarks = list);
  }

  Future<void> _ensureCover() async {
    try {
      final Book updated = await widget.library.ensureCover(_book);
      if (mounted && updated.coverPath != _book.coverPath) {
        setState(() => _book = updated);
        widget.onChanged?.call();
      }
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _setStatus(ReadingStatus status) async {
    setState(() => _busy = true);
    try {
      final Book updated = await widget.library.setStatus(_book.id, status);
      if (mounted) setState(() => _book = updated);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save status: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _relink() async {
    const XTypeGroup epubGroup = XTypeGroup(
      label: 'EPUB',
      extensions: <String>['epub'],
      mimeTypes: <String>['application/epub+zip'],
    );
    final XFile? picked = await openFile(
      acceptedTypeGroups: <XTypeGroup>[epubGroup],
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final Book updated = await widget.library.relinkBook(
        _book,
        File(picked.path),
      );
      if (mounted) {
        setState(() => _book = updated);
        widget.onChanged?.call();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('File relinked.')));
      }
    } on EpubValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not a valid EPUB: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Relink failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove({required bool downloadOnly}) async {
    setState(() => _busy = true);
    try {
      if (!await confirmBookRemoval(
        context,
        widget.library,
        _book,
        downloadOnly: downloadOnly,
      )) {
        return;
      }
      final updated = await widget.library.bookById(_book.id.value);
      widget.onChanged?.call();
      if (!mounted) return;
      if (downloadOnly && updated != null) {
        setState(() => _book = updated);
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open({ReadingLocator? locator}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          source: _book.localAssetPath!,
          title: _book.title,
          initialStatus: _book.readingStatus,
          initialStatusManual: _book.readingStatusManual,
          initialLocator: locator ?? _book.locator,
          bookId: _book.id.value,
          library: widget.library,
          onFinished: () => _setStatus(ReadingStatus.completed),
          onAddBookmark: (location) =>
              widget.library.addBookmark(_book.id, location),
        ),
      ),
    );
    final updated = await widget.library.bookById(_book.id.value);
    if (mounted && updated != null) setState(() => _book = updated);
    await _loadBookmarks();
    widget.onChanged?.call();
  }

  void _openReaderSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsHost(
          service: SettingsService(widget.library),
          child: ReaderSettingsPage(settings: SettingsService(widget.library)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool missing =
        _book.localAssetPath != null &&
        !File(_book.localAssetPath!).existsSync();
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(kSpace4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SketchPage(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace4,
            vertical: kSpace3,
          ),
          children: <Widget>[
            if (_book.coverPath != null && File(_book.coverPath!).existsSync())
              Center(
                child: Image.file(
                  File(_book.coverPath!),
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            const SizedBox(height: kSpace3),
            Text(_book.title, style: Theme.of(context).textTheme.headlineSmall),
            if (_book.authors.isNotEmpty)
              Text(
                _book.authors.join(', '),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (_book.series != null)
              Text(
                _book.seriesIndex == null
                    ? _book.series!
                    : '${_book.series!} #${_book.seriesIndex}',
                style: const TextStyle(fontSize: 13.5, color: kInkMuted),
              ),
            const SizedBox(height: kSpace4),
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: <Widget>[
                SketchBadge(
                  label: _book.readingStatus.label,
                  color: kAccent,
                  seedKey: 'status-${_book.readingStatus.name}',
                ),
                SketchBadge(
                  label: _book.remoteIdentity == null
                      ? 'Local'
                      : 'Remote (CWNG)',
                  seedKey:
                      'source-${_book.remoteIdentity == null ? 'local' : 'remote'}',
                ),
                if (_book.progressPercentage != null)
                  SketchBadge(
                    label: '${(_book.progressPercentage! * 100).round()}% read',
                    color: kAccent,
                    seedKey: 'progress',
                  ),
              ],
            ),
            const SizedBox(height: kSpace4),
            _DetailsTable(book: _book, missing: missing),
            if (_book.description != null &&
                _book.description!.isNotEmpty) ...<Widget>[
              const SizedBox(height: kSpace4),
              const SketchSectionHeading('Description'),
              const SizedBox(height: kSpace2),
              Text(
                _book.description!,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: kInk,
                ),
              ),
            ],
            const SizedBox(height: kSpace4),
            const SketchSectionHeading('Bookmarks'),
            const SizedBox(height: kSpace2),
            if (_bookmarks.isEmpty)
              const Text(
                'No bookmarks yet. Use the bookmark icon while reading.',
                style: TextStyle(fontSize: 13.5, color: kInkMuted),
              ),
            for (final Bookmark bm in _bookmarks)
              Padding(
                padding: const EdgeInsets.only(bottom: kSpace2),
                child: SketchSurface(
                  seedKey: 'bookmark-${bm.id.value}',
                  padding: const EdgeInsets.all(kSpace3),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.bookmark_outline,
                        size: 20,
                        color: kInkMuted,
                      ),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              bm.label ?? 'Bookmark',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: kInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bm.locator.percentage == null
                                  ? (bm.locator.cfi ?? '')
                                  : '${(bm.locator.percentage! * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: kInkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SketchIconButton(
                        icon: Icons.menu_book_outlined,
                        tooltip: 'Open at bookmark',
                        onPressed: missing || _book.localAssetPath == null
                            ? null
                            : () => _open(locator: bm.locator),
                      ),
                      SketchIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete bookmark',
                        onPressed: () async {
                          await widget.library.deleteBookmark(bm.id);
                          await _loadBookmarks();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (_conflicts.isNotEmpty) ...<Widget>[
              const SizedBox(height: kSpace4),
              const SketchSectionHeading('Sync conflicts'),
              const SizedBox(height: kSpace2),
              for (final BookConflict c in _conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: kSpace2),
                  child: SketchSurface(
                    seedKey: 'conflict-${c.id}',
                    strokeColor: kAccent,
                    padding: const EdgeInsets.all(kSpace3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Field: ${c.field}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kInk,
                          ),
                        ),
                        const SizedBox(height: kSpace1),
                        Text(
                          'Local: ${c.localValue}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kInkMuted,
                          ),
                        ),
                        Text(
                          'Remote: ${c.remoteValue}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kInkMuted,
                          ),
                        ),
                        const SizedBox(height: kSpace2),
                        Wrap(
                          spacing: kSpace2,
                          children: <Widget>[
                            SketchButton(
                              label: 'Resolve',
                              onPressed: () async {
                                final ConflictStore? cs =
                                    widget.library.conflicts;
                                if (cs != null) await cs.resolve(c.id);
                                await _loadConflicts();
                              },
                            ),
                            TextButton(
                              onPressed: _loadConflicts,
                              child: const Text('Defer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: kSpace5),
            const SketchSectionHeading('Actions'),
            const SizedBox(height: kSpace3),
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: <Widget>[
                SketchButton(
                  label: 'Open',
                  icon: Icons.menu_book_outlined,
                  filled: true,
                  seedKey: 'open-book',
                  onPressed: _busy || missing || _book.localAssetPath == null
                      ? null
                      : () => _open(),
                ),
                if (missing || _book.localAssetPath == null)
                  SketchButton(
                    label: 'Relink file',
                    icon: Icons.link,
                    seedKey: 'relink',
                    onPressed: _busy ? null : _relink,
                  ),
                PopupMenuButton<ReadingStatus>(
                  tooltip: 'Change status',
                  onSelected: _setStatus,
                  itemBuilder: (BuildContext ctx) =>
                      <PopupMenuEntry<ReadingStatus>>[
                        for (final ReadingStatus s in ReadingStatus.values)
                          PopupMenuItem<ReadingStatus>(
                            value: s,
                            child: Text(s.label),
                          ),
                      ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: kSpace3),
                    child: Chip(label: Text('Change status')),
                  ),
                ),
                SketchButton(
                  label: 'Remove local import',
                  icon: Icons.delete_outline,
                  seedKey: 'remove-import',
                  onPressed: _busy || _book.remoteIdentity != null
                      ? null
                      : () => _remove(downloadOnly: false),
                ),
                if (_book.localAssetPath != null)
                  SketchButton(
                    label: 'Remove download',
                    icon: Icons.delete_forever,
                    seedKey: 'remove-download',
                    onPressed: _busy ? null : () => _remove(downloadOnly: true),
                  ),
                SketchButton(
                  label: 'Reader defaults',
                  icon: Icons.text_fields,
                  seedKey: 'reader-defaults',
                  onPressed: _openReaderSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Label/value metadata table. No card: whitespace and alignment group it.
class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.book, required this.missing});

  final Book book;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      ('Status', book.readingStatus.label),
      (
        'Status source',
        book.readingStatusManual ? 'Manual · local only' : 'Automatic/default',
      ),
      ('Download', book.downloadState.name),
      ('Source', book.remoteIdentity == null ? 'Local' : 'Remote (CWNG)'),
      if (book.progressPercentage != null)
        ('Progress', '${(book.progressPercentage! * 100).round()}%'),
      if (book.addedAt != null)
        ('Added', book.addedAt!.toLocal().toString().split('.').first),
      if (book.lastReadAt != null)
        ('Last read', book.lastReadAt!.toLocal().toString().split('.').first),
      ('File', missing ? 'MISSING' : (book.localAssetPath ?? '—')),
      if (book.localAssetSha256 != null)
        ('SHA-256', '${book.localAssetSha256}'),
      if (book.localAssetRevision != null)
        ('Revision', '${book.localAssetRevision}'),
    ];
    return Column(
      children: <Widget>[
        for (final (String, String) row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 96,
                  child: Text(
                    row.$1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kInkMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: row.$1 == 'File' && row.$2 == 'MISSING'
                          ? kAccent
                          : kInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
