import 'dart:convert';

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.margin = 20,
    this.theme = 'light',
    this.layout = 'scrolled',
    this.highContrast = false,
    this.reducedMotion = false,
  });

  final double fontSize;
  final double lineHeight;
  final double margin;
  final String theme;
  final String layout;
  final bool highContrast;
  final bool reducedMotion;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    String? theme,
    String? layout,
    bool? highContrast,
    bool? reducedMotion,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
        theme: theme ?? this.theme,
        layout: layout ?? this.layout,
        highContrast: highContrast ?? this.highContrast,
        reducedMotion: reducedMotion ?? this.reducedMotion,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'margin': margin,
        'theme': theme,
        'layout': layout,
        'highContrast': highContrast,
        'reducedMotion': reducedMotion,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) => ReaderSettings(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
        margin: (json['margin'] as num?)?.toDouble() ?? 20,
        theme: json['theme'] as String? ?? 'light',
        layout: json['layout'] as String? ?? 'scrolled',
        highContrast: json['highContrast'] as bool? ?? false,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
      );

  static ReaderSettings fromJsonString(String raw) {
    try {
      return ReaderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReaderSettings();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
