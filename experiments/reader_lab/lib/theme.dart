import 'package:benchmark_core/benchmark_core.dart';
import 'package:epub_rtl/epub_rtl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

class LabColors {
  final Color background;
  final Color foreground;
  final Color accent;

  const LabColors({
    required this.background,
    required this.foreground,
    required this.accent,
  });
}

LabColors colorsFor(ReaderTheme theme) => switch (theme) {
      ReaderTheme.light => const LabColors(
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF1B1B1B),
          accent: Color(0xFF1565C0),
        ),
      ReaderTheme.dark => const LabColors(
          background: Color(0xFF121212),
          foreground: Color(0xFFE0E0E0),
          accent: Color(0xFF90CAF9),
        ),
      ReaderTheme.eink => const LabColors(
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF000000),
          accent: Color(0xFF000000),
        ),
    };

EpubReaderSettings epubRtlSettings(ReaderPreferences preferences) {
  final colors = colorsFor(preferences.theme);
  return EpubReaderSettings(
    fontSize: preferences.fontSize,
    lineHeight: preferences.lineHeight,
    paragraphSpacing: preferences.paragraphSpacingEm,
    fontFamily: preferences.fontFamily,
    justify: preferences.textAlign == ReaderTextAlign.justify,
    padding: EdgeInsets.symmetric(
      horizontal: preferences.marginPx,
      vertical: preferences.marginPx,
    ),
    theme: EpubReaderTheme(
      name: preferences.theme.name,
      backgroundColor: colors.background,
      textColor: colors.foreground,
      linkColor: colors.accent,
      secondaryColor: preferences.theme == ReaderTheme.eink
          ? const Color(0xFF000000)
          : const Color(0xFF9E9E9E),
    ),
  );
}

EpubTheme epubJsTheme(ReaderPreferences preferences) {
  final colors = colorsFor(preferences.theme);
  final align = switch (preferences.textAlign) {
    ReaderTextAlign.start => 'start',
    ReaderTextAlign.center => 'center',
    ReaderTextAlign.end => 'end',
    ReaderTextAlign.justify => 'justify',
  };
  final family = preferences.fontFamily ?? 'serif';
  return EpubTheme.custom(
    backgroundDecoration: BoxDecoration(color: colors.background),
    foregroundColor: colors.foreground,
    customCss: {
      'html': {
        'background': _cssHex(colors.background),
        'color': _cssHex(colors.foreground),
      },
      'body': {
        'background': _cssHex(colors.background),
        'color': _cssHex(colors.foreground),
        'font-family': family,
        'line-height': '${preferences.lineHeight}',
        'margin': '${preferences.marginPx}px',
        'text-align': align,
      },
      'p': {
        'margin-bottom': '${preferences.paragraphSpacingEm}em',
        'line-height': '${preferences.lineHeight}',
      },
    },
  );
}

String _cssHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

Map<String, Object?> foliatePreferencePayload(ReaderPreferences preferences) {
  final colors = colorsFor(preferences.theme);
  return {
    'fontSizePx': preferences.fontSize,
    'lineHeight': preferences.lineHeight,
    'paragraphSpacingEm': preferences.paragraphSpacingEm,
    'marginPx': preferences.marginPx,
    'fontFamily': preferences.fontFamily ?? 'serif',
    'textAlign': preferences.textAlign.name,
    'background': _cssHex(colors.background),
    'foreground': _cssHex(colors.foreground),
    'reducedMotion': preferences.reducedMotion,
  };
}
