import 'package:flutter/material.dart';

/// Nocturne design tokens, ported 1:1 from
/// `project/_ds/nocturne-…/styles.css`. Every color, radius and shadow in the
/// app comes from here; never hard-code a hex in a widget.
abstract final class Noc {
  static const bg = Color(0xFF161826);
  static const surface = Color(0xFF232532);
  static const text = Color(0xFFE9E9ED);
  static const accent = Color(0xFF9184D9);

  /// `color-mix(in srgb, #e9e9ed 16%, transparent)`
  static const divider = Color(0x29E9E9ED);

  static const neutral100 = Color(0xFFF3F5FE);
  static const neutral200 = Color(0xFFE4E7F5);
  static const neutral300 = Color(0xFFCFD3E5);
  static const neutral400 = Color(0xFFB2B6CA);
  static const neutral500 = Color(0xFF9397AB);
  static const neutral600 = Color(0xFF75798C);
  static const neutral700 = Color(0xFF595D6C);
  static const neutral800 = Color(0xFF3F424D);
  static const neutral900 = Color(0xFF292B31);

  static const accent100 = Color(0xFFF5F4FF);
  static const accent200 = Color(0xFFE7E5FE);
  static const accent300 = Color(0xFFD2CEFD);
  static const accent400 = Color(0xFFB5ABFC);
  static const accent500 = Color(0xFF968AE0);
  static const accent600 = Color(0xFF796CBF);
  static const accent700 = Color(0xFF5D5294);
  static const accent800 = Color(0xFF423A6A);
  static const accent900 = Color(0xFF2B2741);

  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 14.0;

  static const space1 = 2.8;
  static const space2 = 5.6;
  static const space3 = 8.4;
  static const space4 = 11.2;

  /// `--shadow-lg`: a hairline edge plus ambient darkness.
  static const shadowLg = [
    BoxShadow(color: neutral500, spreadRadius: 1),
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];

  /// `linear-gradient(180deg, surface, bg 40%)` — the screen ground.
  static const screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, bg],
    stops: [0, 0.4],
  );

  /// Text tinted to [pct] of `--color-text` over transparent, as the CSS
  /// `color-mix(in srgb, var(--color-text) N%, transparent)` does.
  static Color textMix(double pct) => text.withValues(alpha: pct);
  static Color accentMix(double pct) => accent.withValues(alpha: pct);

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: bg,
      secondary: accent,
      onSecondary: bg,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: neutral900,
      outline: divider,
      error: Color(0xFFE5877F),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      splashFactory: NoSplash.splashFactory,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accentMix(0.3),
        selectionHandleColor: accent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        hourMinuteColor: neutral900,
        dialBackgroundColor: neutral900,
        dayPeriodBorderSide: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent)),
    );
  }
}

/// The type styles the mockup uses repeatedly. Inter only ships 400 and 500 —
/// Nocturne never bolds past 500.
abstract final class NocText {
  static const kicker = TextStyle(fontSize: 12, color: Noc.neutral300, letterSpacing: 12 * .08);
  static const title = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w500,
    letterSpacing: 34 * -.02,
    height: 1.12,
    color: Noc.text,
  );
  static const titleAside = TextStyle(fontSize: 15, color: Noc.neutral400);
  static const label = TextStyle(fontSize: 13, color: Noc.neutral300);
  static const value = TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Noc.text);
  static const valueUnit = TextStyle(fontSize: 14, color: Noc.neutral400);
  static const small = TextStyle(fontSize: 11, color: Noc.neutral400);
  static const body = TextStyle(fontSize: 13, color: Noc.neutral300, height: 1.5);
}
