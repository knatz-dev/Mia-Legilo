import 'dart:convert';

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.margin = 20,
    this.theme = 'light',
    this.layout = 'scrolled',
  });

  final double fontSize;
  final double lineHeight;
  final double margin;
  final String theme;
  final String layout;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    String? theme,
    String? layout,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
        theme: theme ?? this.theme,
        layout: layout ?? this.layout,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'margin': margin,
        'theme': theme,
        'layout': layout,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) => ReaderSettings(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
        margin: (json['margin'] as num?)?.toDouble() ?? 20,
        theme: json['theme'] as String? ?? 'light',
        layout: json['layout'] as String? ?? 'scrolled',
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
