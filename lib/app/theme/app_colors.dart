import 'package:flutter/material.dart';

/// The app's colour tokens.
///
/// Three groups, kept apart on purpose:
///
///  * a warm neutral ramp, biased toward the crimson accent rather than a flat
///    grey, so surfaces read as lit metal instead of chrome;
///  * the accent pair, crimson and ember, unchanged from the original palette
///    and shared with the boot splash and the map viewer hologram;
///  * semantic state colours, which must never be the accent — a running game
///    and a selected tab cannot be the same colour or neither reads.
class AppColors {
  const AppColors._();

  // ---- Neutral ramp, darkest first ----------------------------------------

  /// Behind everything.
  static const Color void_ = Color(0xFF0C0909);

  /// Default page ground.
  static const Color background = Color(0xFF15100F);

  /// Raised surfaces: panels, cards, inputs.
  static const Color surface = Color(0xFF1D1615);

  /// Surfaces a step above [surface]: hovered rows, the top of a plate.
  static const Color surfaceHigh = Color(0xFF251C1A);

  /// Window furniture and the console shell.
  static const Color titleBar = Color(0xFF120D0D);

  /// Deepest well, used behind terminal text.
  static const Color consoleBg = Color(0xFF0A0708);

  /// Borders and rules.
  static const Color dividerColor = Color(0xFF392724);

  /// A quieter rule, for dividers inside a panel.
  static const Color dividerSoft = Color(0xFF2A1D1B);

  // ---- Accent -------------------------------------------------------------

  static const Color primary = Color(0xFFDC143C);
  static const Color primaryDark = Color(0xFFA01030);
  static const Color secondary = Color(0xFFE85D3A);

  /// The hot core the splash wordmark and the hologram edges bloom toward.
  static const Color core = Color(0xFFFFF1EC);

  // ---- Text ---------------------------------------------------------------

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFEDE3DE);
  static const Color onBackground = Color(0xFFA08F8A);

  /// Least prominent text: hints, units, inactive labels.
  static const Color onSurfaceFaint = Color(0xFF6E605C);

  // ---- State --------------------------------------------------------------

  /// A process is up, a mod is installed, an exit was clean.
  static const Color success = Color(0xFF7FE08A);

  /// Terminal text. Distinct from [success] so a wall of console output does
  /// not read as a wall of success badges.
  static const Color phosphor = Color(0xFF8CE39B);

  static const Color caution = Color(0xFFFFD54F);
  static const Color error = Color(0xFFFF5C5C);

  // ---- Legacy aliases -----------------------------------------------------

  /// Panels used to be their own colour; they are [surface] now.
  static const Color cardColor = surface;
}

/// Shared durations, so the whole app agrees on how fast things move.
///
/// Deliberately short. The launch takeover is the only long animation in the
/// app; everything in the shell should feel mechanical rather than animated.
class AppMotion {
  const AppMotion._();

  /// Hover and press feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// Pressed states.
  static const Duration instant = Duration(milliseconds: 60);

  /// Tab changes and panel swaps.
  static const Duration medium = Duration(milliseconds: 160);

  /// Content entering for the first time.
  static const Duration slow = Duration(milliseconds: 200);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasis = Curves.easeOutBack;
}

/// Shape constants for the notched plate look.
class AppShape {
  const AppShape._();

  /// Size of the 45-degree cut taken out of a panel corner.
  static const double notch = 14;

  /// Smaller cut for controls.
  static const double notchSmall = 8;

  /// The one radius in the app, for things Material insists on rounding.
  static const double radius = 3;
}
