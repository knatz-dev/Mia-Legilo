import 'dart:convert';

import '../../library/library_service.dart';
import 'settings_model.dart';

/// Keys used for persisted settings. One place per setting, one editor.
class SettingKeys {
  static const String libraryDefaults = 'settings.libraryDefaults';
  static const String libraryBehaviour = 'settings.libraryBehaviour';
  static const String appearance = 'settings.appearance';
  static const String readerDefaults = 'settings.readerDefaults';

  /// Connection profiles (non-secret fields only).
  static const String connections = 'settings.connections';

  /// Legacy reader key kept so an existing install keeps its preferences.
  static const String legacyReader = 'reader.settings';

  /// Historical library preference key, read once for migration.
  static const String legacyAutoStart = 'library.autoStartReading';
}

/// Reads and writes every app-wide setting through [LibraryService.store].
///
/// Each setting has exactly one editor: the dedicated settings page for its
/// group. Temporary controls on the library screen write to `library.query`
/// in main.dart and never here.
class SettingsService {
  SettingsService(this._library);

  final LibraryService _library;

  LibraryService get library => _library;

  Future<LibraryDefaults> libraryDefaults() async {
    final String? raw = await _library.store.readSetting(
      SettingKeys.libraryDefaults,
    );
    return raw == null
        ? const LibraryDefaults()
        : LibraryDefaults.fromJsonString(raw);
  }

  Future<void> saveLibraryDefaults(LibraryDefaults value) => _library.store
      .writeSetting(SettingKeys.libraryDefaults, value.toJsonString());

  Future<LibraryBehaviour> libraryBehaviour() async {
    final String? raw = await _library.store.readSetting(
      SettingKeys.libraryBehaviour,
    );
    if (raw != null) return LibraryBehaviour.fromJsonString(raw);
    // Preserve the historical key for the auto-start preference.
    final String? legacy = await _library.store.readSetting(
      SettingKeys.legacyAutoStart,
    );
    return LibraryBehaviour(autoStartReading: legacy != 'false');
  }

  Future<void> saveLibraryBehaviour(LibraryBehaviour value) async {
    await _library.store.writeSetting(
      SettingKeys.libraryBehaviour,
      value.toJsonString(),
    );
    // Keep the reader's own read in sync so behaviour stays consistent.
    await _library.store.writeSetting(
      SettingKeys.legacyAutoStart,
      value.autoStartReading.toString(),
    );
  }

  Future<AppearanceSettings> appearance() async {
    final String? raw = await _library.store.readSetting(
      SettingKeys.appearance,
    );
    return raw == null
        ? const AppearanceSettings()
        : AppearanceSettings.fromJsonString(raw);
  }

  Future<void> saveAppearance(AppearanceSettings value) =>
      _library.store.writeSetting(SettingKeys.appearance, value.toJsonString());

  Future<ReaderDefaults> readerDefaults() async {
    final String? raw = await _library.store.readSetting(
      SettingKeys.readerDefaults,
    );
    if (raw != null) return ReaderDefaults.fromJsonString(raw);
    final String? legacy = await _library.store.readSetting(
      SettingKeys.legacyReader,
    );
    if (legacy == null) return const ReaderDefaults();
    try {
      return ReaderDefaults.fromJson(
        jsonDecode(legacy) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ReaderDefaults();
    }
  }

  Future<void> saveReaderDefaults(ReaderDefaults value) async {
    await _library.store.writeSetting(
      SettingKeys.readerDefaults,
      value.toJsonString(),
    );
    // Keep the reader's legacy key in sync for one release so an in-flight
    // reader page never observes a different value.
    await _library.store.writeSetting(
      SettingKeys.legacyReader,
      value.toJsonString(),
    );
  }

  Future<List<ConnectionProfile>> connections() async {
    final String? raw = await _library.store.readSetting(
      SettingKeys.connections,
    );
    if (raw == null || raw.isEmpty) return const <ConnectionProfile>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map(
            (Map m) => ConnectionProfile.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return const <ConnectionProfile>[];
    }
  }

  Future<void> saveConnections(List<ConnectionProfile> profiles) =>
      _library.store.writeSetting(
        SettingKeys.connections,
        jsonEncode(profiles.map((ConnectionProfile p) => p.toJson()).toList()),
      );
}
