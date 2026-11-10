import 'dart:io';

import 'bookmark.dart';
import 'json_file.dart';
import 'reading_location.dart';

/// Local bookmark list. One file, no network, no Drift.
class BookmarkStore {
  BookmarkStore(File file) : _file = JsonFile(file);

  final JsonFile _file;
  List<Bookmark> _items = const [];

  List<Bookmark> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final json = await _file.read();
    final raw = json['bookmarks'];
    if (raw is! List) {
      _items = const [];
      return;
    }
    _items = [
      for (final entry in raw)
        if (entry is Map)
          Bookmark.fromJson(entry.cast<String, Object?>()),
    ];
  }

  Future<void> _save() => _file.write({
        'bookmarks': [for (final item in _items) item.toJson()],
      });

  /// Bookmark for the current anchor, if one exists.
  Bookmark? matching({
    required String bookId,
    required ReadingLocation location,
  }) {
    for (final item in _items) {
      if (item.bookId == bookId && item.location.sameAnchor(location)) {
        return item;
      }
    }
    return null;
  }

  /// Adds [bookmark] or removes the existing anchor. Returns true when the
  /// anchor is bookmarked afterwards.
  Future<bool> toggle(Bookmark bookmark) async {
    final existing = matching(
      bookId: bookmark.bookId,
      location: bookmark.location,
    );
    if (existing != null) {
      _items = [
        for (final item in _items)
          if (item.id != existing.id) item,
      ];
      await _save();
      return false;
    }
    _items = [..._items, bookmark];
    await _save();
    return true;
  }

  Future<void> delete(String id) async {
    _items = [for (final item in _items) if (item.id != id) item];
    await _save();
  }

  List<Bookmark> forBook(String bookId, String engineId) => [
        for (final item in _items)
          if (item.bookId == bookId && item.engineId == engineId) item,
      ];
}
