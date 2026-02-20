import 'package:flutter/material.dart';

/// Typography tokens.
/// Source: tercen-style design-tokens.md
class AppTextStyles {
  AppTextStyles._();

  // Font families
  static const String fontFamily = 'Fira Sans';
  static const String fontFamilyMono = 'SF Mono';

  // Headings
  static const TextStyle h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.25);
  static const TextStyle h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25);
  static const TextStyle h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);

  // Body
  static const TextStyle bodyLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle body = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);

  // Labels
  static const TextStyle label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.5);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.5);

  // Section header (UPPERCASE, used in left panel)
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.25,
  );
}
