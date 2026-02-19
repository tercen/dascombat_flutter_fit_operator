import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// ACTIONS section: Done button + status text display.
///
/// Done button is disabled until isComputed is true (PCA has been computed).
///
/// WIRING PATTERN:
///   ElevatedButton.onPressed -> provider.onDone() -> notifyListeners() -> main content rebuilds
class ActionsSection extends StatelessWidget {
  const ActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final mutedColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    final canSave = provider.isComputed && !provider.isSaving && !provider.hasSaved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Done button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSave ? () => provider.onDone() : null,
            icon: provider.isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FaIcon(FontAwesomeIcons.check, size: 14),
            label: Text(provider.hasSaved ? 'Saved' : 'Done'),
          ),
        ),

        const SizedBox(height: AppSpacing.controlSpacing),

        // Status display (read-only)
        Text(
          provider.statusMessage,
          style: AppTextStyles.bodySmall.copyWith(color: mutedColor),
        ),
      ],
    );
  }
}
