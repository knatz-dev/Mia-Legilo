import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/annotation.dart';
import '../../domain/book.dart';
import '../../domain/locator.dart';
import '../../domain/status.dart';
import '../../library/epub_inspector.dart';
import '../../library/library_service.dart';
import '../reader/reader_page.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _ensureCover();
    _loadBookmarks();
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
      final Book updated = _book.copyWith(
        readingStatus: status,
        readingStatusManual: true,
      );
      await widget.library.store.save(updated);
      await widget.library.store.upsertSearchIndex(updated);
      if (mounted) setState(() => _book = updated);
      widget.onChanged?.call();
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
    final XFile? picked =
        await openFile(acceptedTypeGroups: <XTypeGroup>[epubGroup]);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File relinked.')),
        );
      }
    } on EpubValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not a valid EPUB: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Relink failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove({required bool deleteAsset}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text(deleteAsset
            ? 'Delete the book and its local file.'
            : 'Remove the book from the library, keeping the file.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      if (deleteAsset) {
        for (final String? path in <String?>[_book.localAssetPath, _book.coverPath]) {
          if (path == null) continue;
          try {
            final File f = File(path);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }
      await widget.library.store.delete(_book.id);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool missing = _book.localAssetPath != null &&
        !File(_book.localAssetPath!).existsSync();
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (_busy) const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_book.coverPath != null && File(_book.coverPath!).existsSync())
            Center(
              child: Image.file(
                File(_book.coverPath!),
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 12),
          Text(_book.title, style: Theme.of(context).textTheme.headlineSmall),
          if (_book.authors.isNotEmpty)
            Text(_book.authors.join(', '),
                style: Theme.of(context).textTheme.titleMedium),
          if (_book.series != null)
            Text(
              _book.seriesIndex == null
                  ? _book.series!
                  : '${_book.series!} #${_book.seriesIndex}',
            ),
          const SizedBox(height: 12),
          _row('Status', _book.readingStatus.label),
          _row('Download', _book.downloadState.name),
          _row('Source',
              _book.remoteIdentity == null ? 'Local' : 'Remote (CWNG)'),
          if (_book.progressPercentage != null)
            _row('Progress', '${(_book.progressPercentage! * 100).round()}%'),
          if (_book.addedAt != null)
            _row('Added', _book.addedAt!.toLocal().toString().split('.').first),
          if (_book.lastReadAt != null)
            _row('Last read', _book.lastReadAt!.toLocal().toString().split('.').first),
          if (_book.description != null && _book.description!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Description', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(_book.description!),
          ],
          const SizedBox(height: 12),
          _row('File', missing ? 'MISSING' : (_book.localAssetPath ?? '—')),
          if (_book.localAssetSha256 != null)
            _row('SHA-256', _book.localAssetSha256!),
          if (_book.localAssetRevision != null)
            _row('Revision', '${_book.localAssetRevision}'),
          const SizedBox(height: 12),
          Text('Bookmarks', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (_bookmarks.isEmpty)
            const Text('No bookmarks yet. Use the bookmark icon while reading.'),
          for (final Bookmark bm in _bookmarks)
            ListTile(
              dense: true,
              title: Text(bm.label ?? 'Bookmark'),
              subtitle: Text(
                bm.locator.percentage == null
                    ? (bm.locator.cfi ?? '')
                    : '${(bm.locator.percentage! * 100).round()}%',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.menu_book),
                    tooltip: 'Open at bookmark',
                    onPressed: _book.localAssetPath == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReaderPage(
                                  source: _book.localAssetPath!,
                                  title: _book.title,
                                  initialStatus: _book.readingStatus,
                                  initialStatusManual: _book.readingStatusManual,
                                  onFinished: () =>
                                      _setStatus(ReadingStatus.completed),
                                  onAddBookmark: (ReadingLocator locator) async {
                                    await widget.library
                                        .addBookmark(_book.id, locator);
                                    await _loadBookmarks();
                                  },
                                  onProgress: (ReadingLocator locator) async {},
                                  library: widget.library,
                                ),
                              ),
                            );
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.library.deleteBookmark(bm.id);
                      await _loadBookmarks();
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ElevatedButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('Open'),
                onPressed: missing || _book.localAssetPath == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReaderPage(
                              source: _book.localAssetPath!,
                              title: _book.title,
                              initialStatus: _book.readingStatus,
                              initialStatusManual: _book.readingStatusManual,
                              onFinished: () => _setStatus(ReadingStatus.completed),
                              onAddBookmark: (ReadingLocator locator) async {
                                await widget.library.addBookmark(_book.id, locator);
                                await _loadBookmarks();
                              },
                            ),
                          ),
                        );
                      },
              ),
              if (missing)
                OutlinedButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Relink file'),
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
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Chip(label: Text('Change status')),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                onPressed: _busy ? null : () => _remove(deleteAsset: false),
              ),
              if (_book.localAssetPath != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete file too'),
                  onPressed: _busy ? null : () => _remove(deleteAsset: true),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
