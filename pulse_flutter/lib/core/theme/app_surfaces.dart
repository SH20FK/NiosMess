import 'package:material_ui/material_ui.dart';

/// Neutral app chrome. Accent colors still come from the user's palette.
///
/// Depth here is tonal only: shadows, surface tint and blurs are banned (see
/// AGENTS.md), so the `surfaceContainer` ladder has to carry every level of
/// elevation by itself. The steps are spaced by at least 3 L* so a card, a row
/// and a nested block stay readable next to each other:
///
/// | token                     | light     | L*    | CR vs surface |
/// |---------------------------|-----------|-------|---------------|
/// | `surface`                 | `#F2F2F2` | 95.49 | 1.00          |
/// | `surfaceContainerLow`     | `#EFEFEF` | 94.45 | 1.03          |
/// | `surfaceContainer`        | `#E6E6E6` | 91.29 | 1.12          |
/// | `surfaceContainerHigh`    | `#DCDCDC` | 87.76 | 1.23          |
/// | `surfaceContainerHighest` | `#CFCFCF` | 83.12 | 1.39          |
///
/// The dark ladder keeps the AMOLED-friendly near-black surface (`#1A1A1A`)
/// and opens up to `#404040` the same way (steps of 3.5-5.4 L*).
abstract final class AppSurfaces {
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF2F2F2);

  static Color of(BuildContext context) =>
      background(Theme.of(context).brightness);

  static ColorScheme neutralize(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return scheme.copyWith(
      surface: background(scheme.brightness),
      // surfaceDim sits below the whole container ladder (recessed chrome
      // behind modals), so it stays darker than surfaceContainerHighest.
      surfaceDim: dark ? const Color(0xFF141414) : const Color(0xFFC9C9C9),
      surfaceBright: dark ? const Color(0xFF4A4A4A) : const Color(0xFFF9F9F9),
      surfaceContainerLowest: dark
          ? const Color(0xFF141414)
          : const Color(0xFFFCFCFC),
      surfaceContainerLow: dark
          ? const Color(0xFF212121)
          : const Color(0xFFEFEFEF),
      surfaceContainer: dark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6),
      surfaceContainerHigh: dark
          ? const Color(0xFF343434)
          : const Color(0xFFDCDCDC),
      surfaceContainerHighest: dark
          ? const Color(0xFF404040)
          : const Color(0xFFCFCFCF),
      onSurface: dark ? const Color(0xFFE6E6E6) : const Color(0xFF1C1C1C),
      onSurfaceVariant: dark
          ? const Color(0xFFBEBEBE)
          : const Color(0xFF505050),
      outline: dark ? const Color(0xFF8C8C8C) : const Color(0xFF747474),
      outlineVariant: dark ? const Color(0xFF454545) : const Color(0xFFC7C7C7),
      inverseSurface: dark ? const Color(0xFFE6E6E6) : const Color(0xFF303030),
      onInverseSurface: dark
          ? const Color(0xFF303030)
          : const Color(0xFFF0F0F0),
    );
  }
}
