import 'dart:convert';

/// How much of [ReadingLocation] is a stable semantic anchor.
///
/// [exact] means the identity is a semantic locator (EPUB CFI, or a spine
/// item plus a content-element index). A within-block fraction stored beside
/// it is a layout hint and is not the identity.
///
/// [approximate] means the only available position is a percentage or other
/// non-semantic offset. Callers must not treat it as an exact location.
enum LocationPrecision { exact, approximate }

/// A reading position reported by one engine.
///
/// Engines leave fields null when they do not expose them. [progress] is
/// always approximate when present and is never the bookmark identity.
class ReadingLocation {
  const ReadingLocation({
    required this.engineId,
    required this.precision,
    this.epubCfi,
    this.spineIndex,
    this.progress,
    this.nativeLocator,
  });

  final String engineId;
  final LocationPrecision precision;
  final String? epubCfi;
  final int? spineIndex;

  /// Whole-book fraction in the range 0..1. Approximate. Not an identity.
  final double? progress;

  /// Engine-native locator fields, preserved without reinterpretation.
  final Map<String, Object?>? nativeLocator;

  Map<String, Object?> toJson() => {
        'engineId': engineId,
        'precision': precision.name,
        'epubCfi': epubCfi,
        'spineIndex': spineIndex,
        'progress': progress,
        'nativeLocator': nativeLocator,
      };

  factory ReadingLocation.fromJson(Map<String, Object?> json) {
    final native = json['nativeLocator'];
    return ReadingLocation(
      engineId: json['engineId']! as String,
      precision: LocationPrecision.values.byName(json['precision']! as String),
      epubCfi: json['epubCfi'] as String?,
      spineIndex: (json['spineIndex'] as num?)?.toInt(),
      progress: (json['progress'] as num?)?.toDouble(),
      nativeLocator: native is Map
          ? native.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }

  String encode() => jsonEncode(toJson());

  factory ReadingLocation.decode(String value) =>
      ReadingLocation.fromJson(jsonDecode(value) as Map<String, Object?>);

  /// True when [other] is the same semantic anchor in the same engine.
  ///
  /// Percentage progress is ignored. A CFI match wins. Otherwise the spine
  /// index plus the native `element` index match. Locations that only have a
  /// percentage do not match.
  bool sameAnchor(ReadingLocation other) {
    if (engineId != other.engineId) return false;
    final anchor = nativeLocator?['anchorId'];
    final otherAnchor = other.nativeLocator?['anchorId'];
    if (anchor != null && otherAnchor != null) return anchor == otherAnchor;
    final cfi = epubCfi;
    final otherCfi = other.epubCfi;
    if (cfi != null && cfi.isNotEmpty && otherCfi != null && otherCfi.isNotEmpty) {
      return cfi == otherCfi;
    }
    if (spineIndex != null &&
        other.spineIndex != null &&
        spineIndex == other.spineIndex) {
      final element = nativeLocator?['element'];
      final otherElement = other.nativeLocator?['element'];
      if (element != null || otherElement != null) {
        return element == otherElement;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingLocation &&
      other.engineId == engineId &&
      other.precision == precision &&
      other.epubCfi == epubCfi &&
      other.spineIndex == spineIndex &&
      other.progress == progress &&
      _mapEquals(other.nativeLocator, nativeLocator);

  @override
  int get hashCode => Object.hash(
        engineId,
        precision,
        epubCfi,
        spineIndex,
        progress,
        nativeLocator == null ? null : Object.hashAll(nativeLocator!.entries),
      );

  static bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
