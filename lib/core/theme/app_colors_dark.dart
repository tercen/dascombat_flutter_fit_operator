import 'dart:ui';

/// Dark theme color tokens.
/// Source: tercen-style design-tokens.md
class AppColorsDark {
  AppColorsDark._();

  // Primary (teal for dark theme)
  static const Color primary = Color(0xFF14B8A6);
  static const Color primaryDarker = Color(0xFF0D9488);
  static const Color primaryLighter = Color(0xFF2DD4BF);
  static const Color primarySurface = Color(0xFF153D47);
  static const Color primaryBg = Color(0xFF122E35);

  // Neutrals (inverted)
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral50 = Color(0xFFF8FAFC);

  // Semantic text
  static const Color textPrimary = neutral50;
  static const Color textSecondary = neutral200;
  static const Color textTertiary = neutral400;
  static const Color textMuted = neutral500;
  static const Color textDisabled = neutral600;

  // Backgrounds
  static const Color background = Color(0xFF0F172A);
  static const Color surface = neutral900;
  static const Color surfaceElevated = neutral800;
  static const Color panelBackground = neutral900;

  // Borders
  static const Color border = Color(0xFF334155);
  static const Color borderSubtle = neutral700;

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);

  // Links (distinct from primary actions)
  static const Color link = Color(0xFF60A5FA);
  static const Color linkHover = Color(0xFF3B82F6);
}
