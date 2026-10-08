library;

/// ICON Billing Studio - theming.
///
/// Ported from the web prototype's css/tokens.css and css/themes.css.
/// The entire app and every invoice template re-skin from one accent colour,
/// mirroring the prototype's single `--accent` CSS variable.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

/* ---------------------------------------------------------------- surfaces */

/// Dark foundation (the prototype's default).
class _Dark {
  static const bg = Color(0xFF0E0F13);
  static const bgElevated = Color(0xFF16181F);
  static const surface = Color(0xFF1B1E26);
  static const surface2 = Color(0xFF22262F);
  static const surface3 = Color(0xFF2A2F3A);
  static const border = Color(0xFF2C313C);
  static const borderStrong = Color(0xFF3A404D);
  static const text = Color(0xFFF4F5F7);
  static const text2 = Color(0xFFB9BEC9);
  static const text3 = Color(0xFF7E8494);
}

/// Light foundation.
class _Light {
  static const bg = Color(0xFFF6F7F9);
  static const bgElevated = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1F3F6);
  static const surface3 = Color(0xFFE4E8EE);
  static const border = Color(0xFFDDE2EA);
  static const borderStrong = Color(0xFFC4CBD6);
  static const text = Color(0xFF14161B);
  static const text2 = Color(0xFF4A5260);
  static const text3 = Color(0xFF7E8798);
}

/* ---------------------------------------------------------------- palette */

/// Semantic colours shared by both themes.
const successColor = Color(0xFF22C55E);
const warningColor = Color(0xFFF5C518);
const dangerColor = Color(0xFFEF4444);
const infoColor = Color(0xFF3B82F6);

Color statusColor(String id) => Color(statusById(id).color);

/* ---------------------------------------------------------------- AppColors */

/// Resolved colour set. Kept explicit (not ColorScheme arithmetic) so the
/// values stay close to the prototype's tokens.
class AppColors {
  final Color bg;
  final Color bgElevated;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color accentTint; // ~6% accent wash for chips and table bands

  const AppColors({
    required this.bg,
    required this.bgElevated,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.accentTint,
  });

  factory AppColors.dark(int accent, [int? accentSoft]) => AppColors(
        bg: _Dark.bg,
        bgElevated: _Dark.bgElevated,
        surface: _Dark.surface,
        surface2: _Dark.surface2,
        surface3: _Dark.surface3,
        border: _Dark.border,
        borderStrong: _Dark.borderStrong,
        text: _Dark.text,
        text2: _Dark.text2,
        text3: _Dark.text3,
        accent: Color(accent),
        accentSoft: Color(accentSoft ?? accent),
        onAccent: _onColor(Color(accent)),
        accentTint: Color(accent).withValues(alpha: 0.10),
      );

  factory AppColors.light(int accent, [int? accentSoft]) => AppColors(
        bg: _Light.bg,
        bgElevated: _Light.bgElevated,
        surface: _Light.surface,
        surface2: _Light.surface2,
        surface3: _Light.surface3,
        border: _Light.border,
        borderStrong: _Light.borderStrong,
        text: _Light.text,
        text2: _Light.text2,
        text3: _Light.text3,
        accent: Color(accent),
        accentSoft: Color(accentSoft ?? accent),
        onAccent: _onColor(Color(accent)),
        accentTint: Color(accent).withValues(alpha: 0.08),
      );

  /// Contrast-safe text colour for a filled accent background.
  static Color _onColor(Color c) {
    final luminance = (0.299 * (c.r * 255) + 0.587 * (c.g * 255) + 0.114 * (c.b * 255)) / 255;
    return luminance > 0.62 ? const Color(0xFF14161B) : Colors.white;
  }

  /// Darken/lighten a colour by a signed fraction (the prototype's shade()).
  static Color shade(Color c, double f) {
    int apply(int v) {
      if (f >= 0) return (v + (255 - v) * f).round().clamp(0, 255);
      return (v * (1 + f)).round().clamp(0, 255);
    }

    return Color.fromARGB(
      (c.a * 255).round(),
      apply((c.r * 255).round()),
      apply((c.g * 255).round()),
      apply((c.b * 255).round()),
    );
  }
}

/* ---------------------------------------------------------------- AppTheme */

class AppTheme {
  /// Build [ThemeData] from the stored theme name and accent.
  static ThemeData of(BuildContext context, String themeId, AccentDef accent) {
    final dark = themeId != 'light';
    final colors =
        dark ? AppColors.dark(accent.a, accent.aSoft) : AppColors.light(accent.a, accent.aSoft);
    return _build(colors, dark);
  }

  static ThemeData _build(AppColors c, bool dark) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      }),
    );

    final display = GoogleFonts.poppins();
    final body = GoogleFonts.inter();

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: base.brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.accentSoft,
        onSecondary: c.onAccent,
        error: dangerColor,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.text,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: display.copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: c.text, height: 1.15),
        displayMedium: display.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: c.text, height: 1.2),
        headlineSmall: display.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: c.text),
        titleLarge: display.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: c.text),
        titleMedium: display.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text),
        bodyLarge: body.copyWith(fontSize: 14, color: c.text, height: 1.5),
        bodyMedium: body.copyWith(fontSize: 13, color: c.text2, height: 1.5),
        bodySmall: body.copyWith(fontSize: 11.5, color: c.text3, height: 1.45),
        labelLarge: display.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
        labelSmall: body.copyWith(fontSize: 10.5, color: c.text3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.text,
        centerTitle: false,
        titleTextStyle: display.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.border, width: 0.6),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 0.6,
        space: 0.6,
      ),
      dividerColor: c.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: body.copyWith(color: c.text3, fontSize: 13),
        labelStyle: body.copyWith(color: c.text3, fontSize: 11.5),
        floatingLabelStyle: body.copyWith(color: c.accent, fontSize: 11.5, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dangerColor, width: 0.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: display.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: display.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          side: BorderSide(color: c.borderStrong, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: display.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text2,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        selectedColor: c.accent,
        labelStyle: body.copyWith(fontSize: 12, color: c.text2, fontWeight: FontWeight.w500),
        side: BorderSide(color: c.border, width: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: display.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: c.text),
        contentTextStyle: body.copyWith(fontSize: 13.5, color: c.text2, height: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface3,
        contentTextStyle: body.copyWith(fontSize: 13, color: c.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCloseIcon: false,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surface3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onAccent;
          return dark ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return dark ? const Color(0xFF2A2F3A) : const Color(0xFFE8EAEE);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.text3,
        indicatorColor: c.accent,
        labelStyle: display.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: display.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.text,
        iconColor: c.text2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/* ---------------------------------------------------------------- extension */

/// Contrast-safe text colour for a filled background.
Color onAccentOf(Color c) {
  final luminance = (0.299 * (c.r * 255) + 0.587 * (c.g * 255) + 0.114 * (c.b * 255)) / 255;
  return luminance > 0.62 ? const Color(0xFF14161B) : Colors.white;
}

/// Read the resolved colours anywhere in the tree.
AppColors colors(BuildContext context) {
  final t = Theme.of(context);
  final dark = t.brightness == Brightness.dark;
  final accent = t.colorScheme.primary;
  final soft = t.colorScheme.secondary;
  return _lookup.putIfAbsent(accent.toARGB32(), () {
    final value = accent.toARGB32();
    return dark ? AppColors.dark(value, soft.toARGB32()) : AppColors.light(value, soft.toARGB32());
  });
}

final Map<int, AppColors> _lookup = {};
