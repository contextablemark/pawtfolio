import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette — lifted from the catalog theme block / the mockup.
const Color pawTeal = Color(0xFF01696F);
const Color pawOrange = Color(0xFFDA7101);
const Color pawMagenta = Color(0xFFA12C7B);
const Color pawGreen = Color(0xFF437A22);
const Color pawCream = Color(0xFFF9F8F5);
const Color pawMuted = Color(0xFFC8C2B6);
const Color pawInk = Color(0xFF3A352E); // warm dark text

/// Accent colors carried through `ThemeData` so custom A2UI widgets can resolve
/// them — genui does NOT apply the A2UI `theme` block, so the palette must
/// travel via the theme and be read with `Theme.of(context)`.
@immutable
class PawColors extends ThemeExtension<PawColors> {
  const PawColors({
    required this.teal,
    required this.orange,
    required this.magenta,
    required this.green,
    required this.muted,
  });

  final Color teal;
  final Color orange;
  final Color magenta;
  final Color green;
  final Color muted;

  /// Resolves an accent key (`teal`|`orange`|`magenta`|`green`|`muted`).
  Color byKey(String? key) => switch (key) {
    'orange' => orange,
    'magenta' => magenta,
    'green' => green,
    'muted' => muted,
    _ => teal,
  };

  @override
  PawColors copyWith({
    Color? teal,
    Color? orange,
    Color? magenta,
    Color? green,
    Color? muted,
  }) => PawColors(
    teal: teal ?? this.teal,
    orange: orange ?? this.orange,
    magenta: magenta ?? this.magenta,
    green: green ?? this.green,
    muted: muted ?? this.muted,
  );

  @override
  PawColors lerp(ThemeExtension<PawColors>? other, double t) {
    if (other is! PawColors) return this;
    return PawColors(
      teal: Color.lerp(teal, other.teal, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      magenta: Color.lerp(magenta, other.magenta, t)!,
      green: Color.lerp(green, other.green, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

const PawColors _pawColors = PawColors(
  teal: pawTeal,
  orange: pawOrange,
  magenta: pawMagenta,
  green: pawGreen,
  muted: pawMuted,
);

/// Resolves an accent-key (from A2UI data) to a color via the theme.
Color accentColor(BuildContext context, String? key) =>
    (Theme.of(context).extension<PawColors>() ?? _pawColors).byKey(key);

/// The mockup's signature: a flat **solid-color circle with a white pictogram**.
/// Use it as the leading icon on cards / section headings.
Widget pawIconBadge(IconData icon, Color color, {double size = 36}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  alignment: Alignment.center,
  child: Icon(icon, color: Colors.white, size: size * 0.56),
);

ThemeData buildPawtfolioTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: pawTeal,
    primary: pawTeal,
    secondary: pawOrange,
    tertiary: pawMagenta,
    surface: pawCream,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  // Body: Nunito (warm, rounded humanist sans). Headings: Oswald (condensed),
  // teal, with letter-spacing — the mockup's "teal condensed section heading".
  final bodyTheme = GoogleFonts.nunitoTextTheme(
    base.textTheme,
  ).apply(bodyColor: pawInk, displayColor: pawTeal);

  TextStyle head(TextStyle? s, {double spacing = 0.4}) => GoogleFonts.oswald(
    textStyle: s,
  ).copyWith(color: pawTeal, fontWeight: FontWeight.w600, letterSpacing: spacing);

  final textTheme = bodyTheme.copyWith(
    displayLarge: head(bodyTheme.displayLarge),
    displayMedium: head(bodyTheme.displayMedium),
    displaySmall: head(bodyTheme.displaySmall),
    headlineLarge: head(bodyTheme.headlineLarge),
    headlineMedium: head(bodyTheme.headlineMedium),
    headlineSmall: head(bodyTheme.headlineSmall, spacing: 0.2),
    titleLarge: head(bodyTheme.titleLarge),
    titleMedium: head(bodyTheme.titleMedium, spacing: 0.2),
    titleSmall: head(bodyTheme.titleSmall, spacing: 0.2),
  );

  return base.copyWith(
    scaffoldBackgroundColor: pawCream,
    extensions: const [_pawColors],
    textTheme: textTheme,
    // Flat + warm: no shadow, a hairline teal border, cream-white fill.
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pawTeal.withValues(alpha: 0.12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: pawOrange.withValues(alpha: 0.10),
      side: BorderSide(color: pawOrange.withValues(alpha: 0.30)),
      labelStyle: GoogleFonts.nunito(
        color: pawInk,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}
