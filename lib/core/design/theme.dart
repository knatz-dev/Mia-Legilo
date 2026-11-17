import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// The app's typeface. Declared, not bundled, so the app never waits on a
/// network font; the fallback list keeps the same proportions.
const String kFontFamily = 'Instrument Sans';
const List<String> kFontFallback = <String>[
  'Inter',
  'Roboto',
  'system-ui',
  'sans-serif',
];

TextStyle _style(
  double fontSize,
  FontWeight weight,
  Color color, {
  double height = 1.45,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: kFontFamily,
  fontFamilyFallback: kFontFallback,
  fontSize: fontSize,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Builds the app text theme.
TextTheme buildMiaLegiloTextTheme() {
  final TextTheme base = Typography.englishLike2021;
  return base.copyWith(
    displaySmall: _style(32, FontWeight.w700, kInk, height: 1.2),
    headlineMedium: _style(28, FontWeight.w700, kInk, height: 1.25),
    headlineSmall: _style(24, FontWeight.w700, kInk, height: 1.25),
    titleLarge: _style(20, FontWeight.w700, kInk, height: 1.3),
    titleMedium: _style(16, FontWeight.w600, kInk, height: 1.4),
    titleSmall: _style(14, FontWeight.w600, kInk, height: 1.4),
    bodyLarge: _style(kBodySize, FontWeight.w400, kInk, height: 1.5),
    bodyMedium: _style(14, FontWeight.w400, kInk, height: 1.5),
    bodySmall: _style(12.5, FontWeight.w400, kInkMuted, height: 1.45),
    labelLarge: _style(15, FontWeight.w600, kInk, height: 1.3),
    labelMedium: _style(13, FontWeight.w600, kInkMuted, height: 1.3),
    labelSmall: _style(12, FontWeight.w600, kInkMuted, letterSpacing: 0.3),
  );
}

/// Colour roles the theme builder needs, so light and dark share one layout
/// and differ only in palette.
class _Palette {
  const _Palette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.inkDisabled,
    required this.accent,
    required this.accentFill,
    required this.borderInk,
    required this.borderFaint,
  });

  final Color paper;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color inkDisabled;
  final Color accent;
  final Color accentFill;
  final Color borderInk;
  final Color borderFaint;
}

const _Palette _lightPalette = _Palette(
  paper: kPaper,
  surface: kPaperSurface,
  ink: kInk,
  inkMuted: kInkMuted,
  inkDisabled: kInkDisabled,
  accent: kAccent,
  accentFill: kAccentFill,
  borderInk: kBorderInk,
  borderFaint: kBorderFaint,
);

/// Same warm palette inverted: the accent stays the single saturated colour.
const _Palette _darkPalette = _Palette(
  paper: kPaperDark,
  surface: kPaperSurfaceDark,
  ink: kInkDark,
  inkMuted: kInkMutedDark,
  inkDisabled: kInkDisabledDark,
  accent: kAccent,
  accentFill: kAccentFillDark,
  borderInk: kBorderInkDark,
  borderFaint: kBorderFaintDark,
);

/// Builds the light app theme from the shared tokens.
ThemeData buildMiaLegiloTheme() => _buildTheme(_lightPalette);

/// Builds the dark app theme. Same type, spacing and sketch tokens as the
/// light theme; only the palette changes.
ThemeData buildMiaLegiloDarkTheme() => _buildTheme(_darkPalette);

ThemeData _buildTheme(_Palette p) {
  final ColorScheme scheme = ColorScheme.light(
    primary: p.accent,
    onPrimary: p.paper,
    primaryContainer: p.accentFill,
    onPrimaryContainer: p.accent,
    secondary: p.inkMuted,
    onSecondary: p.paper,
    secondaryContainer: p.accentFill,
    onSecondaryContainer: p.ink,
    surface: p.paper,
    onSurface: p.ink,
    surfaceContainerHighest: p.surface,
    onSurfaceVariant: p.inkMuted,
    outline: p.borderInk,
    outlineVariant: p.borderFaint,
    error: p.accent,
    onError: p.paper,
    errorContainer: p.accentFill,
    onErrorContainer: p.accent,
  );

  final TextTheme text = buildMiaLegiloTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.accentFill.withValues(alpha: 0.45),
    textTheme: text,
    primaryTextTheme: text,
    typography: Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _style(19, FontWeight.w700, p.ink),
    ),
    dividerTheme: DividerThemeData(
      color: p.borderFaint,
      thickness: 1,
      space: 1,
    ),
    dividerColor: p.borderFaint,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpace3,
        vertical: kSpace3,
      ),
      hintStyle: TextStyle(color: p.inkDisabled, fontSize: 15),
      labelStyle: TextStyle(color: p.inkMuted, fontSize: 15),
      floatingLabelStyle: TextStyle(color: p.accent, fontSize: 14),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: p.borderInk, width: kStrokeHairline),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.borderInk, width: kStrokeHairline),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.accent, width: kStrokeFocus),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.accent, width: kStrokeHairline),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.accent, width: kStrokeFocus),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accentFill,
      selectionHandleColor: p.accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? p.accent : p.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? p.accentFill : p.surface,
      ),
      trackOutlineColor: WidgetStatePropertyAll(p.borderInk),
      trackOutlineWidth: const WidgetStatePropertyAll(1.4),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? p.accentFill : p.surface,
      ),
      checkColor: WidgetStatePropertyAll(p.accent),
      side: BorderSide(color: p.borderInk, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? p.accent : p.surface,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.borderFaint,
      thumbColor: p.accent,
      overlayColor: p.accentFill,
      trackHeight: 3,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.borderFaint,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.accent,
      unselectedLabelColor: p.inkMuted,
      indicatorColor: p.accent,
      dividerColor: p.borderFaint,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surface,
      contentTextStyle: TextStyle(color: p.ink, fontSize: 14.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: p.borderInk, width: kStrokeHairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: p.borderInk, width: kStrokeHairline),
      ),
      titleTextStyle: _style(19, FontWeight.w700, p.ink),
      contentTextStyle: _style(14.5, FontWeight.w400, p.ink, height: 1.5),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
        side: BorderSide(color: p.borderInk, width: kStrokeHairline),
      ),
      showDragHandle: false,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.ink,
      textColor: p.ink,
      contentPadding: EdgeInsets.symmetric(horizontal: kSpace4),
      minVerticalPadding: kSpace2,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: TextStyle(color: p.ink, fontSize: 14.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: p.borderInk, width: kStrokeHairline),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            side: BorderSide(color: p.borderInk, width: kStrokeHairline),
          ),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: TextStyle(color: p.paper, fontSize: 12.5),
      decoration: BoxDecoration(color: p.ink),
    ),
    buttonTheme: const ButtonThemeData(
      shape: RoundedRectangleBorder(),
      padding: EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
      minWidth: 96,
      height: kMinTarget,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        minimumSize: Size(72, kMinTarget),
        textStyle: _style(14.5, FontWeight.w600, p.accent),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.paper,
        minimumSize: const Size(72, kMinTarget),
        shape: RoundedRectangleBorder(),
        textStyle: _style(15, FontWeight.w600, p.paper),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: Size(72, kMinTarget),
        side: BorderSide(color: p.borderInk, width: kStrokeBold),
        shape: RoundedRectangleBorder(),
        textStyle: _style(15, FontWeight.w600, p.ink),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accentFill,
        foregroundColor: p.ink,
        elevation: 0,
        minimumSize: const Size(72, kMinTarget),
        shape: const RoundedRectangleBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.accentFill,
      labelStyle: TextStyle(color: p.ink, fontSize: 14),
      secondaryLabelStyle: TextStyle(color: p.accent, fontSize: 14),
      side: BorderSide(color: p.borderInk, width: kStrokeHairline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.symmetric(horizontal: kSpace3),
      showCheckmark: false,
    ),
    focusColor: p.accent,
    hoverColor: p.accentFill.withValues(alpha: 0.5),
    splashColor: p.accentFill,
  );
}
