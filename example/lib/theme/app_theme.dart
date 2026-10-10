import 'package:flutter/material.dart';

/// Font families bundled in `assets/fonts/` (see pubspec.yaml).
abstract final class AppFonts {
  /// UI text (docs website: `--ifm-font-family-base`).
  static const sans = 'Rethink Sans';

  /// Ids, config ids, event rows (docs website: `--ifm-font-family-monospace`).
  static const mono = 'JetBrains Mono';

  /// A JetBrains Mono style. Use for config ids / ad unit ids / event rows.
  static TextStyle monoStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: mono,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontVariations: [FontVariation.weight(fontWeight.value.toDouble())],
    color: color,
  );
}

/// The docs website palette (`website/src/css/custom.css`) as a
/// [ThemeExtension]. Read it with `DemoColors.of(context)`.
///
/// | token | light | dark | CSS |
/// |---|---|---|---|
/// | primary | #f67725 | #f67725 | `--asx-green` |
/// | primaryStrong | #dc5e09 | #ffa05e | `--asx-teal` (links, active text) |
/// | ink / inkDeep | #002745 / #001c33 | same | navbar |
/// | secondary | #2681d2 | #2681d2 | `--asx-orange` |
/// | mint | #fff1e6 | #3d2412 | selected backgrounds |
/// | surface | #f6f7f8 | #00223d | |
/// | border | #e2e7ee | #143a5c | |
/// | muted | #5f6678 | #90aabf | |
/// | codeBg / codeFg | #f1f4f8 / #004586 | #002340 / #cceaff | |
/// | danger / dangerBg | #b42318 / #fef3f2 | #fda29b / #3a1714 | |
@immutable
class DemoColors extends ThemeExtension<DemoColors> {
  const DemoColors({
    required this.primary,
    required this.primaryStrong,
    required this.ink,
    required this.inkDeep,
    required this.secondary,
    required this.mint,
    required this.surface,
    required this.border,
    required this.muted,
    required this.codeBg,
    required this.codeFg,
    required this.danger,
    required this.dangerBg,
    required this.background,
    required this.text,
    required this.heading,
  });
  final Color primary;
  final Color primaryStrong;
  final Color ink;
  final Color inkDeep;
  final Color secondary;
  final Color mint;
  final Color surface;
  final Color border;
  final Color muted;
  final Color codeBg;
  final Color codeFg;
  final Color danger;
  final Color dangerBg;
  final Color background;
  final Color text;
  final Color heading;

  static const light = DemoColors(
    primary: Color(0xFFF67725),
    primaryStrong: Color(0xFFDC5E09),
    ink: Color(0xFF002745),
    inkDeep: Color(0xFF001C33),
    secondary: Color(0xFF2681D2),
    mint: Color(0xFFFFF1E6),
    surface: Color(0xFFF6F7F8),
    border: Color(0xFFE2E7EE),
    muted: Color(0xFF5F6678),
    codeBg: Color(0xFFF1F4F8),
    codeFg: Color(0xFF004586),
    danger: Color(0xFFB42318),
    dangerBg: Color(0xFFFEF3F2),
    background: Color(0xFFFFFFFF),
    text: Color(0xFF002745),
    heading: Color(0xFF001C33),
  );

  static const dark = DemoColors(
    primary: Color(0xFFF67725),
    primaryStrong: Color(0xFFFFA05E),
    ink: Color(0xFF002745),
    inkDeep: Color(0xFF001C33),
    secondary: Color(0xFF2681D2),
    mint: Color(0xFF3D2412),
    surface: Color(0xFF00223D),
    border: Color(0xFF143A5C),
    muted: Color(0xFF90AABF),
    codeBg: Color(0xFF002340),
    codeFg: Color(0xFFCCEAFF),
    danger: Color(0xFFFDA29B),
    dangerBg: Color(0xFF3A1714),
    background: Color(0xFF00172B),
    text: Color(0xFFE4EBF2),
    heading: Color(0xFFF4F7FB),
  );

  static DemoColors of(BuildContext context) =>
      Theme.of(context).extension<DemoColors>() ?? light;

  @override
  DemoColors copyWith() => this;

  @override
  DemoColors lerp(DemoColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DemoColors(
      primary: l(primary, other.primary),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      ink: l(ink, other.ink),
      inkDeep: l(inkDeep, other.inkDeep),
      secondary: l(secondary, other.secondary),
      mint: l(mint, other.mint),
      surface: l(surface, other.surface),
      border: l(border, other.border),
      muted: l(muted, other.muted),
      codeBg: l(codeBg, other.codeBg),
      codeFg: l(codeFg, other.codeFg),
      danger: l(danger, other.danger),
      dangerBg: l(dangerBg, other.dangerBg),
      background: l(background, other.background),
      text: l(text, other.text),
      heading: l(heading, other.heading),
    );
  }
}

/// Light and dark [ThemeData] in the docs website style: navy app bar and
/// bottom bar, Prebid orange accent, 10–12 px radii, Rethink Sans.
abstract final class AppTheme {
  static const radius = 10.0;
  static const radiusLarge = 12.0;

  static ThemeData light() => _build(DemoColors.light, Brightness.light);
  static ThemeData dark() => _build(DemoColors.dark, Brightness.dark);

  static ThemeData _build(DemoColors c, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: brightness,
        ).copyWith(
          primary: c.primary,
          onPrimary: Colors.white,
          secondary: c.secondary,
          onSecondary: Colors.white,
          error: c.danger,
          surface: c.background,
          onSurface: c.text,
          onSurfaceVariant: c.muted,
          outline: c.border,
          outlineVariant: c.border,
          surfaceContainerHighest: c.surface,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return base.copyWith(
      textTheme: _withWeightAxis(
        base.textTheme.apply(bodyColor: c.text, displayColor: c.heading),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.ink,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontVariations: [FontVariation.weight(700)],
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.inkDeep,
        indicatorColor: c.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? c.primary
                : Colors.white.withValues(alpha: 0.78),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontVariations: [FontVariation.weight(selected ? 700 : 500)],
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.78),
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        textColor: c.text,
        iconColor: c.muted,
        selectedColor: c.primaryStrong,
        selectedTileColor: c.mint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.border,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.surface,
          disabledForegroundColor: c.muted,
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation.weight(700)],
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primaryStrong,
          side: BorderSide(color: c.border),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primaryStrong),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: c.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inkDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Variable fonts don't pick their `wght` instance from [FontWeight] on
  /// every engine, so set the axis explicitly for each text style.
  static TextTheme _withWeightAxis(TextTheme t) {
    TextStyle? w(TextStyle? s) {
      final weight = s?.fontWeight ?? FontWeight.w400;
      return s?.copyWith(
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
      );
    }

    return t.copyWith(
      displayLarge: w(t.displayLarge),
      displayMedium: w(t.displayMedium),
      displaySmall: w(t.displaySmall),
      headlineLarge: w(t.headlineLarge),
      headlineMedium: w(t.headlineMedium),
      headlineSmall: w(t.headlineSmall),
      titleLarge: w(t.titleLarge),
      titleMedium: w(t.titleMedium),
      titleSmall: w(t.titleSmall),
      bodyLarge: w(t.bodyLarge),
      bodyMedium: w(t.bodyMedium),
      bodySmall: w(t.bodySmall),
      labelLarge: w(t.labelLarge),
      labelMedium: w(t.labelMedium),
      labelSmall: w(t.labelSmall),
    );
  }
}
