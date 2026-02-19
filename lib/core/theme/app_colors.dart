import 'dart:ui';

/// Light theme color tokens.
/// Source: tercen-style design-tokens.md
class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryDarker = Color(0xFF1E3A8A);
  static const Color primaryLighter = Color(0xFF2563EB);
  static const Color primarySurface = Color(0xFFDBEAFE);
  static const Color primaryBg = Color(0xFFEFF6FF);

  // Neutrals
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic text
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral700;
  static const Color textTertiary = neutral600;
  static const Color textMuted = neutral500;
  static const Color textDisabled = neutral400;

  // Backgrounds
  static const Color background = neutral100;
  static const Color surface = white;
  static const Color surfaceElevated = neutral200;
  static const Color panelBackground = neutral50;

  // Borders
  static const Color border = neutral300;
  static const Color borderSubtle = neutral200;

  // Status
  static const Color success = Color(0xFF047857);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFB45309);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF0E7490);
  static const Color infoLight = Color(0xFFCFFAFE);

  // Links
  static const Color link = primary;
  static const Color linkHover = primaryDarker;
}
