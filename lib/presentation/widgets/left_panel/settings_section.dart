import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// SETTINGS section: Model type dropdown, Reference batch dropdown, Save model toggle.
///
/// All controls are disabled (dimmed but visible) when mode is "Apply Model".
///
/// WIRING PATTERN:
///   control.onChanged -> provider.setXxx(value) -> notifyListeners() -> main content rebuilds
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final labelColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    // Controls are disabled when in Apply Model mode
    final isDisabled = provider.mode == 'Apply Model';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Model type dropdown
        Text('Model type', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            value: provider.modelType,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(value: 'L/S', child: Text('L/S')),
              DropdownMenuItem(value: 'L', child: Text('L')),
            ],
            onChanged: isDisabled
                ? null
                : (value) {
                    if (value != null) provider.setModelType(value);
                  },
          ),
        ),

        const SizedBox(height: AppSpacing.controlSpacing),

        // Reference batch dropdown
        Text('Ref. batch', style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<String>(
            value: provider.referenceBatch,
            decoration: const InputDecoration(),
            items: [
              const DropdownMenuItem(value: 'None', child: Text('None')),
              ...provider.batchLabels.map((batch) {
                return DropdownMenuItem(value: batch, child: Text(batch));
              }),
            ],
            onChanged: isDisabled
                ? null
                : (value) {
                    if (value != null) provider.setReferenceBatch(value);
                  },
          ),
        ),

        const SizedBox(height: AppSpacing.controlSpacing),

        // Save model toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Save model', style: AppTextStyles.label.copyWith(color: labelColor)),
            Switch(
              value: provider.saveModel,
              onChanged: isDisabled ? null : provider.setSaveModel,
            ),
          ],
        ),
      ],
    );
  }
}
