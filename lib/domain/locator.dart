/// Semantic reading locator. Percentages are approximate display metadata only.
enum LocatorPrecision { exact, converted, approximate }

class ReadingLocator {
  const ReadingLocator({
    this.cfi,
    this.anchor,
    this.spineItem,
    this.chapterIndex,
    this.percentage,
    this.precision = LocatorPrecision.approximate,
  });

  /// Durable semantic anchor (EPUB CFI or documented equivalent).
  final String? cfi;

  /// Documented equivalent anchor when CFI unavailable.
  final String? anchor;

  /// Spine item / chapter resource identifier.
  final String? spineItem;

  /// Zero-based chapter index.
  final int? chapterIndex;

  /// Approximate display progression (0.0–1.0). Never authoritative.
  final double? percentage;

  final LocatorPrecision precision;

  bool get hasExactAnchor => cfi != null || anchor != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cfi': cfi,
        'anchor': anchor,
        'spineItem': spineItem,
        'chapterIndex': chapterIndex,
        'percentage': percentage,
        'precision': precision.name,
      };

  factory ReadingLocator.fromJson(Map<String, dynamic> json) => ReadingLocator(
        cfi: json['cfi'] as String?,
        anchor: json['anchor'] as String?,
        spineItem: json['spineItem'] as String?,
        chapterIndex: json['chapterIndex'] as int?,
        percentage: (json['percentage'] as num?)?.toDouble(),
        precision: LocatorPrecision.values.firstWhere(
          (p) => p.name == json['precision'],
          orElse: () => LocatorPrecision.approximate,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is ReadingLocator &&
      other.cfi == cfi &&
      other.anchor == anchor &&
      other.spineItem == spineItem &&
      other.chapterIndex == chapterIndex &&
      other.percentage == percentage &&
      other.precision == precision;

  @override
  int get hashCode => Object.hash(cfi, anchor, spineItem, chapterIndex, percentage, precision);
}
