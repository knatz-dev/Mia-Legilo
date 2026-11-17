import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../library/library_query.dart';

/// Saved defaults for the temporary library controls (search, sort, filter,
/// view). These are defaults, not the live controls: the live controls stay
/// on the library screen and remain temporary until changed.
@immutable
class LibraryDefaults {
  const LibraryDefaults({
    this.viewMode = LibraryViewMode.list,
    this.sort = LibrarySortKey.title,
    this.direction = LibrarySortDirection.ascending,
    this.groupBy = LibraryGroupBy.none,
    this.statuses = const <String>{},
    this.sourceFilter = LibrarySourceFilter.all,
    this.availabilityFilter = LibraryAvailabilityFilter.all,
  });

  final LibraryViewMode viewMode;
  final LibrarySortKey sort;
  final LibrarySortDirection direction;
  final LibraryGroupBy groupBy;

  /// Reading statuses selected by default. Empty means "all statuses".
  final Set<String> statuses;
  final LibrarySourceFilter sourceFilter;
  final LibraryAvailabilityFilter availabilityFilter;

  LibraryDefaults copyWith({
    LibraryViewMode? viewMode,
    LibrarySortKey? sort,
    LibrarySortDirection? direction,
    LibraryGroupBy? groupBy,
    Set<String>? statuses,
    LibrarySourceFilter? sourceFilter,
    LibraryAvailabilityFilter? availabilityFilter,
  }) => LibraryDefaults(
    viewMode: viewMode ?? this.viewMode,
    sort: sort ?? this.sort,
    direction: direction ?? this.direction,
    groupBy: groupBy ?? this.groupBy,
    statuses: statuses ?? this.statuses,
    sourceFilter: sourceFilter ?? this.sourceFilter,
    availabilityFilter: availabilityFilter ?? this.availabilityFilter,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'viewMode': viewMode.name,
    'sort': sort.name,
    'direction': direction.name,
    'groupBy': groupBy.name,
    'statuses': statuses.toList(),
    'sourceFilter': sourceFilter.name,
    'availabilityFilter': availabilityFilter.name,
  };

  factory LibraryDefaults.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, dynamic name, T fallback) =>
        values.firstWhere((T v) => v.name == name, orElse: () => fallback);
    return LibraryDefaults(
      viewMode: pick(
        LibraryViewMode.values,
        json['viewMode'],
        LibraryViewMode.list,
      ),
      sort: pick(LibrarySortKey.values, json['sort'], LibrarySortKey.title),
      direction: pick(
        LibrarySortDirection.values,
        json['direction'],
        LibrarySortDirection.ascending,
      ),
      groupBy: pick(
        LibraryGroupBy.values,
        json['groupBy'],
        LibraryGroupBy.none,
      ),
      statuses: json['statuses'] is List
          ? (json['statuses'] as List).whereType<String>().toSet()
          : const <String>{},
      sourceFilter: pick(
        LibrarySourceFilter.values,
        json['sourceFilter'],
        LibrarySourceFilter.all,
      ),
      availabilityFilter: pick(
        LibraryAvailabilityFilter.values,
        json['availabilityFilter'],
        LibraryAvailabilityFilter.all,
      ),
    );
  }

  static LibraryDefaults fromJsonString(String raw) {
    try {
      return LibraryDefaults.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LibraryDefaults();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}

/// App-wide appearance preference for the app chrome (not the reader).
enum AppThemeMode { light, dark, system }

/// Reader defaults. Kept here so the reader settings page and the reader
/// sheet read and write the same keys.
@immutable
class ReaderDefaults {
  const ReaderDefaults({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.margin = 20,
    this.theme = 'light',
    this.layout = 'scrolled',
    this.reducedMotion = false,
  });

  final double fontSize;
  final double lineHeight;
  final double margin;
  final String theme;
  final String layout;
  final bool reducedMotion;

  ReaderDefaults copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    String? theme,
    String? layout,
    bool? reducedMotion,
  }) => ReaderDefaults(
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    margin: margin ?? this.margin,
    theme: theme ?? this.theme,
    layout: layout ?? this.layout,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'margin': margin,
    'theme': theme,
    'layout': layout,
    'reducedMotion': reducedMotion,
  };

  factory ReaderDefaults.fromJson(Map<String, dynamic> json) => ReaderDefaults(
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
    lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
    margin: (json['margin'] as num?)?.toDouble() ?? 20,
    theme: json['theme'] as String? ?? 'light',
    layout: json['layout'] as String? ?? 'scrolled',
    reducedMotion: json['reducedMotion'] as bool? ?? false,
  );

  static ReaderDefaults fromJsonString(String raw) {
    try {
      return ReaderDefaults.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReaderDefaults();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}

/// Library behaviour that is app-wide, not a temporary view control.
@immutable
class LibraryBehaviour {
  const LibraryBehaviour({this.autoStartReading = true});

  /// Whether reading activity moves an unread/Want-to-Read book to Reading.
  final bool autoStartReading;

  LibraryBehaviour copyWith({bool? autoStartReading}) => LibraryBehaviour(
    autoStartReading: autoStartReading ?? this.autoStartReading,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'autoStartReading': autoStartReading,
  };

  factory LibraryBehaviour.fromJson(Map<String, dynamic> json) =>
      LibraryBehaviour(
        autoStartReading: json['autoStartReading'] as bool? ?? true,
      );

  static LibraryBehaviour fromJsonString(String raw) {
    try {
      return LibraryBehaviour.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LibraryBehaviour();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}

/// App-wide appearance settings.
@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = AppThemeMode.light,
    this.sketchIntensity = SketchIntensity.standard,
  });

  final AppThemeMode themeMode;
  final SketchIntensity sketchIntensity;

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    SketchIntensity? sketchIntensity,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    sketchIntensity: sketchIntensity ?? this.sketchIntensity,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themeMode': themeMode.name,
    'sketchIntensity': sketchIntensity.name,
  };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) =>
      AppearanceSettings(
        themeMode: AppThemeMode.values.firstWhere(
          (AppThemeMode m) => m.name == json['themeMode'],
          orElse: () => AppThemeMode.light,
        ),
        sketchIntensity: SketchIntensity.values.firstWhere(
          (SketchIntensity s) => s.name == json['sketchIntensity'],
          orElse: () => SketchIntensity.standard,
        ),
      );

  static AppearanceSettings fromJsonString(String raw) {
    try {
      return AppearanceSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppearanceSettings();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}

/// A configured CWNG connection profile (SPEC CON-001).
@immutable
class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.serverUrl,
    required this.username,
    this.label,
    this.lastConnectedAt,
  });

  final String id;
  final String serverUrl;
  final String username;
  final String? label;
  final DateTime? lastConnectedAt;

  /// Never serialize credentials; only the non-secret fields.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'serverUrl': serverUrl,
    'username': username,
    'label': label,
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
  };

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) =>
      ConnectionProfile(
        id: json['id'] as String,
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        label: json['label'] as String?,
        lastConnectedAt: json['lastConnectedAt'] == null
            ? null
            : DateTime.tryParse(json['lastConnectedAt'] as String),
      );
}
