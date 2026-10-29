import 'package:flutter/material.dart';

/// Palette du design system « Anneaux » (mode sombre).
class C {
  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF161616);
  static const surface2 = Color(0xFF1F1F1F);
  static const line = Color(0xFF2E2E2E);
  static const text = Color(0xFFF5F5F2);
  static const muted = Color(0xFFA3A3A3);
  static const dim = Color(0xFF8C8C8C);
  static const faint = Color(0xFF5C5C5C);
  static const accent = Color(0xFFFF7A1A);
  static const accentDark = Color(0xFFC85A0C);
  static const accentNight = Color(0xFF2A1606);
}

const kDisplayFont = 'BarlowCondensed';

/// Style « display » : Barlow Condensed, chiffres tabulaires.
/// [ls] est l'espacement en em (comme dans la maquette).
TextStyle disp(
  double size, {
  FontWeight w = FontWeight.w800,
  Color color = C.text,
  double ls = 0,
  double? height,
}) =>
    TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      fontWeight: w,
      color: color,
      letterSpacing: ls * size,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Texte courant (police système).
TextStyle body(double size,
        {Color color = C.text, FontWeight w = FontWeight.w400, double? height}) =>
    TextStyle(fontSize: size, color: color, fontWeight: w, height: height);

/// Texte display en majuscules.
class D extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight w;
  final Color color;
  final double ls;
  final double? height;
  final TextAlign? align;
  final int? maxLines;

  const D(
    this.text, {
    super.key,
    this.size = 20,
    this.w = FontWeight.w800,
    this.color = C.text,
    this.ls = 0,
    this.height,
    this.align,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: disp(size, w: w, color: color, ls: ls, height: height),
      );
}

/// Petit label en capitales espacées (« DERNIÈRE FOIS »).
class Lbl extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const Lbl(this.text, {super.key, this.color = C.muted, this.size = 15});

  @override
  Widget build(BuildContext context) =>
      D(text, size: size, w: FontWeight.w700, ls: 0.14, color: color);
}

ThemeData appTheme() {
  const scheme = ColorScheme.dark(
    primary: C.accent,
    onPrimary: C.bg,
    secondary: C.text,
    onSecondary: C.bg,
    surface: C.bg,
    onSurface: C.text,
    onSurfaceVariant: C.muted,
    surfaceContainerHighest: C.surface2,
    surfaceContainerHigh: C.surface,
    surfaceContainer: C.surface,
    outline: C.line,
    error: Color(0xFFFF5A4E),
  );
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    dividerColor: C.surface2,
    splashFactory: InkRipple.splashFactory,
    dialogTheme: const DialogThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: C.faint,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.text,
      contentTextStyle: body(15, color: C.bg, w: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.line, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.line, width: 2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.accent, width: 2)),
      labelStyle: body(15, color: C.muted),
      hintStyle: body(15, color: C.faint),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.muted,
        textStyle: disp(18, w: FontWeight.w700, ls: 0.06),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: C.bg,
        textStyle: disp(18, w: FontWeight.w800, ls: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.bg : C.bg),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.accent : C.faint),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
