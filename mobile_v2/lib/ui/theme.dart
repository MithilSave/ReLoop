import 'package:flutter/material.dart';

/// Design tokens carried over from the web app: forest-green brand, restrained emerald accent,
/// slightly green-biased neutrals, thin borders, 8–10px radii. Light and dark sets match index.css.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color brand, brand2, brandFg, accent, accentSoft;
  final Color bg, surface, surface2, line, line2;
  final Color fg, fg2, fg3;
  final Color ok, okBg, warn, warnBg, bad, badBg, info, infoBg, neuBg;
  final Color c1, c2, c3, c4, c5, c6;
  final Color side, sideFg, sideAct;

  const AppColors({
    required this.brand,
    required this.brand2,
    required this.brandFg,
    required this.accent,
    required this.accentSoft,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.line2,
    required this.fg,
    required this.fg2,
    required this.fg3,
    required this.ok,
    required this.okBg,
    required this.warn,
    required this.warnBg,
    required this.bad,
    required this.badBg,
    required this.info,
    required this.infoBg,
    required this.neuBg,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.c4,
    required this.c5,
    required this.c6,
    required this.side,
    required this.sideFg,
    required this.sideAct,
  });

  static const AppColors light = AppColors(
    brand: Color(0xFF0F3D2E),
    brand2: Color(0xFF185C45),
    brandFg: Color(0xFFFFFFFF),
    accent: Color(0xFF0E9F6E),
    accentSoft: Color(0xFFE3F4EC),
    bg: Color(0xFFF6F7F6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F3F2),
    line: Color(0xFFE2E6E4),
    line2: Color(0xFFCFD6D3),
    fg: Color(0xFF15201C),
    fg2: Color(0xFF4A5752),
    fg3: Color(0xFF6F7B77),
    ok: Color(0xFF0E7C55),
    okBg: Color(0xFFE3F4EC),
    warn: Color(0xFF9A5806),
    warnBg: Color(0xFFFBF0DC),
    bad: Color(0xFFB42318),
    badBg: Color(0xFFFDECEA),
    info: Color(0xFF2457A6),
    infoBg: Color(0xFFE8EFFA),
    neuBg: Color(0xFFEEF0EF),
    c1: Color(0xFF0F3D2E),
    c2: Color(0xFF2E9B72),
    c3: Color(0xFF8CCBAF),
    c4: Color(0xFFC9A23A),
    c5: Color(0xFFB42318),
    c6: Color(0xFF9AA6A1),
    side: Color(0xFF0F3D2E),
    sideFg: Color(0xFFC8D9D1),
    sideAct: Color(0xFF1C5643),
  );

  static const AppColors dark = AppColors(
    brand: Color(0xFF5FC79C),
    brand2: Color(0xFF7BD3AE),
    brandFg: Color(0xFF0B1310),
    accent: Color(0xFF34C48B),
    accentSoft: Color(0xFF163428),
    bg: Color(0xFF0E1412),
    surface: Color(0xFF151D1A),
    surface2: Color(0xFF1B2521),
    line: Color(0xFF26322D),
    line2: Color(0xFF34433D),
    fg: Color(0xFFE6ECE9),
    fg2: Color(0xFFA9B6B1),
    fg3: Color(0xFF84928C),
    ok: Color(0xFF4CC492),
    okBg: Color(0xFF153227),
    warn: Color(0xFFE3A34B),
    warnBg: Color(0xFF352812),
    bad: Color(0xFFF2766B),
    badBg: Color(0xFF3A1A17),
    info: Color(0xFF7EA8EE),
    infoBg: Color(0xFF1A2740),
    neuBg: Color(0xFF222C28),
    c1: Color(0xFF7BD3AE),
    c2: Color(0xFF3A9E77),
    c3: Color(0xFF2A5E4A),
    c4: Color(0xFFD9B65A),
    c5: Color(0xFFF2766B),
    c6: Color(0xFF5D6B66),
    side: Color(0xFF0B1310),
    sideFg: Color(0xFF9FB2AA),
    sideAct: Color(0xFF173A2D),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => (other is AppColors && t >= 0.5) ? other : this;
}

const String kMono = 'monospace';
const List<String> kMonoFallback = <String>['Roboto Mono', 'Menlo', 'Consolas', 'Courier New'];

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0F3D2E), brightness: b).copyWith(
    primary: c.brand,
    onPrimary: c.brandFg,
    secondary: c.accent,
    surface: c.surface,
    onSurface: c.fg,
    error: c.bad,
    outline: c.line2,
    outlineVariant: c.line,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.line2));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.surface,
    dividerColor: c.line,
    extensions: <ThemeExtension<dynamic>>[c],
    visualDensity: VisualDensity.standard,
    textTheme: Typography.material2021(platform: TargetPlatform.android).black.apply(bodyColor: c.fg, displayColor: c.fg).copyWith(
          bodyMedium: TextStyle(fontSize: 14, color: c.fg, height: 1.45),
        ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: c.accent, width: 1.6)),
      errorBorder: border.copyWith(borderSide: BorderSide(color: c.bad)),
      focusedErrorBorder: border.copyWith(borderSide: BorderSide(color: c.bad, width: 1.6)),
      disabledBorder: border.copyWith(borderSide: BorderSide(color: c.line)),
      hintStyle: TextStyle(color: c.fg3, fontSize: 13.5),
    ),
    snackBarTheme: SnackBarThemeData(backgroundColor: c.brand, contentTextStyle: TextStyle(color: c.brandFg)),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(color: c.surface, surfaceTintColor: Colors.transparent),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : null),
    ),
  );
}

extension AppContext on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>() ?? AppColors.light;
  double get screenW => MediaQuery.sizeOf(this).width;

  /// Desktop layout with sidebar (≥1024px, the web app's `lg` breakpoint).
  bool get wide => screenW >= 1024;

  /// Phone layout (<640px, the web app's `sm` breakpoint).
  bool get phone => screenW < 640;
}
