/// Typography and presentation requested by the lab.
///
/// An engine applies the fields it supports and reports the rest in its
/// capability map. The lab does not silently emulate an unsupported field
/// with a different mechanism.
class ReaderPreferences {
  const ReaderPreferences({
    this.fontSize = 18,
    this.fontFamily,
    this.lineHeight = 1.5,
    this.paragraphSpacingEm = 0.8,
    this.marginPx = 20,
    this.textAlign = ReaderTextAlign.start,
    this.theme = ReaderTheme.light,
    this.reducedMotion = false,
  });

  /// Body size in CSS pixels where the engine uses px, otherwise the
  /// engine's own font-size unit. Documented per engine.
  final double fontSize;
  final String? fontFamily;
  final double lineHeight;
  final double paragraphSpacingEm;
  final double marginPx;
  final ReaderTextAlign textAlign;
  final ReaderTheme theme;
  final bool reducedMotion;

  ReaderPreferences copyWith({
    double? fontSize,
    String? fontFamily,
    bool clearFontFamily = false,
    double? lineHeight,
    double? paragraphSpacingEm,
    double? marginPx,
    ReaderTextAlign? textAlign,
    ReaderTheme? theme,
    bool? reducedMotion,
  }) {
    return ReaderPreferences(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: clearFontFamily ? null : fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacingEm: paragraphSpacingEm ?? this.paragraphSpacingEm,
      marginPx: marginPx ?? this.marginPx,
      textAlign: textAlign ?? this.textAlign,
      theme: theme ?? this.theme,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }

  Map<String, Object?> toJson() => {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'lineHeight': lineHeight,
        'paragraphSpacingEm': paragraphSpacingEm,
        'marginPx': marginPx,
        'textAlign': textAlign.name,
        'theme': theme.name,
        'reducedMotion': reducedMotion,
      };

  @override
  bool operator ==(Object other) =>
      other is ReaderPreferences &&
      other.fontSize == fontSize &&
      other.fontFamily == fontFamily &&
      other.lineHeight == lineHeight &&
      other.paragraphSpacingEm == paragraphSpacingEm &&
      other.marginPx == marginPx &&
      other.textAlign == textAlign &&
      other.theme == theme &&
      other.reducedMotion == reducedMotion;

  @override
  int get hashCode => Object.hash(
        fontSize,
        fontFamily,
        lineHeight,
        paragraphSpacingEm,
        marginPx,
        textAlign,
        theme,
        reducedMotion,
      );

  factory ReaderPreferences.fromJson(Map<String, Object?> json) =>
      ReaderPreferences(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
        fontFamily: json['fontFamily'] as String?,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
        paragraphSpacingEm:
            (json['paragraphSpacingEm'] as num?)?.toDouble() ?? 0.8,
        marginPx: (json['marginPx'] as num?)?.toDouble() ?? 20,
        textAlign: ReaderTextAlign.values.byName(
          (json['textAlign'] as String?) ?? 'start',
        ),
        theme: ReaderTheme.values.byName((json['theme'] as String?) ?? 'light'),
        reducedMotion: json['reducedMotion'] as bool? ?? false,
      );
}

enum ReaderTextAlign { start, center, end, justify }

enum ReaderTheme { light, dark, eink }
