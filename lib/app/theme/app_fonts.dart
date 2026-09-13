/// Font families bundled with the app.
///
/// The Doom 2016 family ships as three cuts. [doomLeft] and [doomRight] carry
/// mirrored bevels and are meant to be paired — each renders one half of a
/// wordmark so the slants meet in the middle, which is how the original logo
/// lockup is built. [doomText] is the upright cut, legible at small sizes.
///
/// These faces are freeware/non-commercial and are not covered by the
/// project's MIT licence; see `assets/fonts/LICENSE.txt`.
class AppFonts {
  const AppFonts._();

  static const String doomText = 'Doom2016Text';
  static const String doomLeft = 'Doom2016Left';
  static const String doomRight = 'Doom2016Right';

  /// The family has no U+2026 glyph, so anything rendered in it must spell an
  /// ellipsis out rather than using the single character.
  static const String ellipsis = '...';
}
