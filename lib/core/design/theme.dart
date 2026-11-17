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

/// Builds the app theme from the shared tokens.
ThemeData buildMiaLegiloTheme() {
  final ColorScheme scheme = ColorScheme.light(
    primary: kAccent,
    onPrimary: kPaper,
    primaryContainer: kAccentFill,
    onPrimaryContainer: kAccent,
    secondary: kInkMuted,
    onSecondary: kPaper,
    secondaryContainer: kAccentFill,
    onSecondaryContainer: kInk,
    surface: kPaper,
    onSurface: kInk,
    surfaceContainerHighest: kPaperSurface,
    onSurfaceVariant: kInkMuted,
    outline: kBorderInk,
    outlineVariant: kBorderFaint,
    error: kAccent,
    onError: kPaper,
    errorContainer: kAccentFill,
    onErrorContainer: kAccent,
  );

  final TextTheme text = buildMiaLegiloTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kPaper,
    canvasColor: kPaper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: kAccentFill.withValues(alpha: 0.45),
    textTheme: text,
    primaryTextTheme: text,
    typography: Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kPaper,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _style(19, FontWeight.w700, kInk),
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderFaint,
      thickness: 1,
      space: 1,
    ),
    dividerColor: kBorderFaint,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kPaperSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpace3,
        vertical: kSpace3,
      ),
      hintStyle: const TextStyle(color: kInkDisabled, fontSize: 15),
      labelStyle: const TextStyle(color: kInkMuted, fontSize: 15),
      floatingLabelStyle: const TextStyle(color: kAccent, fontSize: 14),
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: kBorderInk, width: kStrokeHairline),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kBorderInk, width: kStrokeHairline),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kAccent, width: kStrokeFocus),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kAccent, width: kStrokeHairline),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kAccent, width: kStrokeFocus),
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: kAccent,
      selectionColor: kAccentFill,
      selectionHandleColor: kAccent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? kAccent : kPaperSurface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? kAccentFill : kPaperSurface,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(kBorderInk),
      trackOutlineWidth: const WidgetStatePropertyAll(1.4),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? kAccentFill : kPaperSurface,
      ),
      checkColor: const WidgetStatePropertyAll(kAccent),
      side: const BorderSide(color: kBorderInk, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? kAccent : kPaperSurface,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: kAccent,
      inactiveTrackColor: kBorderFaint,
      thumbColor: kAccent,
      overlayColor: kAccentFill,
      trackHeight: 3,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAccent,
      linearTrackColor: kBorderFaint,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kAccent,
      unselectedLabelColor: kInkMuted,
      indicatorColor: kAccent,
      dividerColor: kBorderFaint,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kPaperSurface,
      contentTextStyle: const TextStyle(color: kInk, fontSize: 14.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: kBorderInk, width: kStrokeHairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kPaperSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: kBorderInk, width: kStrokeHairline),
      ),
      titleTextStyle: _style(19, FontWeight.w700, kInk),
      contentTextStyle: _style(14.5, FontWeight.w400, kInk, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kPaperSurface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: kPaperSurface,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
        side: BorderSide(color: kBorderInk, width: kStrokeHairline),
      ),
      showDragHandle: false,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: kPaperSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kInk,
      textColor: kInk,
      contentPadding: EdgeInsets.symmetric(horizontal: kSpace4),
      minVerticalPadding: kSpace2,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kPaperSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: const TextStyle(color: kInk, fontSize: 14.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: kBorderInk, width: kStrokeHairline),
      ),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(kPaperSurface),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            side: BorderSide(color: kBorderInk, width: kStrokeHairline),
          ),
        ),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      textStyle: TextStyle(color: kPaper, fontSize: 12.5),
      decoration: BoxDecoration(color: kInk),
    ),
    buttonTheme: const ButtonThemeData(
      shape: RoundedRectangleBorder(),
      padding: EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
      minWidth: 96,
      height: kMinTarget,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAccent,
        minimumSize: const Size(72, kMinTarget),
        textStyle: _style(14.5, FontWeight.w600, kAccent),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: kPaper,
        minimumSize: const Size(72, kMinTarget),
        shape: const RoundedRectangleBorder(),
        textStyle: _style(15, FontWeight.w600, kPaper),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        minimumSize: const Size(72, kMinTarget),
        side: const BorderSide(color: kBorderInk, width: kStrokeBold),
        shape: const RoundedRectangleBorder(),
        textStyle: _style(15, FontWeight.w600, kInk),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentFill,
        foregroundColor: kInk,
        elevation: 0,
        minimumSize: const Size(72, kMinTarget),
        shape: const RoundedRectangleBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kPaperSurface,
      selectedColor: kAccentFill,
      labelStyle: const TextStyle(color: kInk, fontSize: 14),
      secondaryLabelStyle: const TextStyle(color: kAccent, fontSize: 14),
      side: const BorderSide(color: kBorderInk, width: kStrokeHairline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.symmetric(horizontal: kSpace3),
      showCheckmark: false,
    ),
    focusColor: kAccent,
    hoverColor: kAccentFill.withValues(alpha: 0.5),
    splashColor: kAccentFill,
  );
}
