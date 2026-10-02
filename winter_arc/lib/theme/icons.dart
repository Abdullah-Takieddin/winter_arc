import 'package:flutter/widgets.dart';

/// The Phosphor glyphs the app uses, from the bundled `@phosphor-icons/web`
/// 2.1.1 fonts (the same build the design loads). Codepoints come from that
/// package's `style.css`.
abstract final class Ph {
  static const _f = 'Phosphor';
  static const alarm = IconData(0xe006, fontFamily: _f);
  static const barbell = IconData(0xe0b6, fontFamily: _f);
  static const calendarBlank = IconData(0xe10a, fontFamily: _f);
  static const chartLineUp = IconData(0xe156, fontFamily: _f);
  static const gear = IconData(0xe270, fontFamily: _f);
  static const minus = IconData(0xe32a, fontFamily: _f);
  static const moon = IconData(0xe330, fontFamily: _f);
  static const pencilSimple = IconData(0xe3b4, fontFamily: _f);
  static const plus = IconData(0xe3d4, fontFamily: _f);
  static const snowflake = IconData(0xe5aa, fontFamily: _f);
  static const sunHorizon = IconData(0xe5b6, fontFamily: _f);
  static const x = IconData(0xe4f6, fontFamily: _f);
}

/// Filled variants, used for active tabs and the streak flame.
abstract final class PhFill {
  static const _f = 'Phosphor-Fill';
  static const barbell = IconData(0xe0b6, fontFamily: _f);
  static const chartLineUp = IconData(0xe156, fontFamily: _f);
  static const flame = IconData(0xe624, fontFamily: _f);
  static const moon = IconData(0xe330, fontFamily: _f);
  static const snowflake = IconData(0xe5aa, fontFamily: _f);
}
