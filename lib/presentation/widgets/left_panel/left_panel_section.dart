import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// A single left panel section with icon, UPPERCASE label, and content.
class LeftPanelSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const LeftPanelSection({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final headerBg = isDark ? AppColorsDark.surfaceElevated : AppColors.surfaceElevated;
    final headerTextColor = isDark ? AppColorsDark.neutral300 : AppColors.textMuted;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Container(
          color: headerBg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: headerTextColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label.toUpperCase(),
                style: AppTextStyles.sectionHeader.copyWith(color: headerTextColor),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: borderColor),
        // Section content
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sectionPadding),
          child: child,
        ),
        Divider(height: 1, thickness: 1, color: borderColor),
      ],
    );
  }
}
