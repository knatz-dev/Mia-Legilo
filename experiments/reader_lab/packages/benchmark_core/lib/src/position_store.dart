import 'dart:io';

import 'json_file.dart';
import 'reading_location.dart';

/// Last semantic reading position per book and engine.
class PositionStore {
  PositionStore(File file) : _file = JsonFile(file);

  final JsonFile _file;
  Map<String, ReadingLocation> _items = {};

  Future<void> load() async {
    final json = await _file.read();
    final raw = json['positions'];
    if (raw is! Map) {
      _items = {};
      return;
    }
    _items = {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): ReadingLocation.fromJson(
            (entry.value as Map).cast<String, Object?>(),
          ),
    };
  }

  ReadingLocation? read(String bookId, String engineId) =>
      _items[_key(bookId, engineId)];

  Future<void> save(String bookId, String engineId, ReadingLocation location) async {
    _items[_key(bookId, engineId)] = location;
    await _file.write({
      'positions': {
        for (final entry in _items.entries) entry.key: entry.value.toJson(),
      },
    });
  }

  static String _key(String bookId, String engineId) => '$engineId::$bookId';
}
